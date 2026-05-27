# Quiver Architecture & Code Quality Review

**Date:** 2026-05-26  
**Scope:** Full codebase review — all Lua files  
**Interface target:** TBC Classic Anniversary 20504

---

## 1. Overall Architecture

### Module interaction graph

```
Quiver.lua (global singleton, AceAddon)
  └── Core/Core.lua           ← orchestrates init/enable order
        ├── Modules/Ammo.lua
        ├── Modules/Mana.lua
        ├── Modules/Aspects.lua
        ├── Modules/Pet.lua   ← reads Data/PetFoods.lua
        ├── Modules/Stings.lua
        ├── Modules/Traps.lua
        └── Modules/Tracking.lua
        └── UI/Sphere.lua     ← calls every module directly
        └── UI/Menus.lua      ← calls modules, owns food picker
              └── UI/Config.lua
```

**Dependency direction is clean but one-sided.** Every module calls `Quiver.UI.Sphere:Update*()` or `Quiver.UI.Menus:Update*()` directly when its own state changes. There is no event bus or observer. This creates **downward coupling from modules into the UI layer** — a module must know the UI is ready before calling it. Core's init order (modules first, UI second) makes this safe during `Initialize()`, but the `Enable()` step does not call `Sphere:Initialize()` or `Menus:Initialize()` — those are called by `Core:Initialize()` directly — so by the time events fire in `Enable()`, the UI frames already exist. This works today, but any module that triggers before `Sphere:Initialize()` completes would crash.

**No circular dependencies detected.**

### What's missing in the design

- No shared event bus or callback system. Modules notify the UI directly, so adding a second UI widget that cares about, say, mana percentage requires modifying `Mana.lua`.
- `Locales/enUS.lua` defines `Quiver.L` but **zero code in any module references `Quiver.L`**. All string literals are hardcoded in modules and UI files. The locale table is dead code.

---

## 2. Event Handling

### Duplicate `PLAYER_ENTERING_WORLD` registrations

Every module registers its own `PLAYER_ENTERING_WORLD` handler via `Quiver:RegisterEvent()`. With AceEvent-3.0 this is fine — each handler is independently registered — but it means the event fires a cascade of 7+ handlers on every zone transition. The practical consequence is a minor CPU spike on load/zone change, not a correctness problem.

`Menus:Initialize()` (`UI/Menus.lua:722-724`) registers `PLAYER_ENTERING_WORLD` **again** in addition to the module-level registrations, so `Menus:RebuildAll()` runs while every module is also refreshing its own state simultaneously. This is redundant but harmless.

### `selectionTicker` runs unconditionally forever

`UI/Menus.lua:22-28`:
```lua
local selectionTicker = CreateFrame("Frame")
selectionTicker:SetScript("OnUpdate", function()
    if pendingSelectionMenu and not InCombatLockdown() then
        ...
    end
end)
```
This `OnUpdate` fires every frame for the entire session even when `pendingSelectionMenu` is nil. The nil guard keeps it cheap, but it is a perpetual overhead. A cleaner pattern is to hide/show the ticker frame to gate the callback.

### Aspects: double detection mechanism

`Modules/Aspects.lua:27-44` registers `UNIT_AURA` **and** creates a 1-second `OnUpdate` ticker to poll aspect state. The comment says `UNIT_AURA` doesn't fire reliably when aspects are cancelled. This polling is intentional but means `DetectCurrentAspect()` iterates all player buffs every second unconditionally for the entire session, even when out of combat. Low cost, but worth noting.

### Mana: triple polling

`Modules/Mana.lua` registers `UNIT_POWER_UPDATE` **and** a 2-second `OnUpdate` ticker on top of `PLAYER_ENTERING_WORLD`. The ticker is redundant — `UNIT_POWER_UPDATE` fires for every mana change. The ticker exists as belt-and-suspenders against edge cases, which is reasonable for a TBC Classic target, but adds a permanently running frame.

### Trap cooldown ticker runs unconditionally

`UI/Menus.lua:728-736`:
```lua
local cdTicker = CreateFrame("Frame")
cdTicker:SetScript("OnUpdate", function(_, dt) ... Menus:UpdateTrapCooldowns() end)
```
This also runs every frame regardless of whether the trap menu is open. `UpdateTrapCooldowns()` iterates all trap buttons, calls `GetSpellCooldown()` five times, and manipulates textures on every 0.1s interval — even when the menu is invisible. This should be gated: enable the ticker when the trap menu opens, disable it when the menu closes.

---

## 3. State Management

### Two-tier storage is correct but inconsistently applied

- `Quiver.db.profile.*` — account-wide/profile settings (sphere position, sounds, click actions)
- `Quiver.db.char.*` — per-character state (`menuSelections`, `lastTracking`, `lastAspect`)

Module-local state (e.g., `Ammo.count`, `Pet.exists`, `Aspects.current`) is stored directly on the module table as plain fields. This is readable and works fine.

**`lastAspect` is defined in defaults but never written.** `Core/Core.lua:26` declares `char.lastAspect = nil`, but no code anywhere in `Modules/Aspects.lua` or elsewhere assigns to it. If the intent was to restore the last aspect on login, this feature is unimplemented.

**`lastTracking` is written but never read.** `Modules/Tracking.lua:40` writes `Quiver.db.char.lastTracking = spellName` on every `Cast()` call. No code reads it back. Dead state.

### Food selection persistence has three parallel save keys

`UI/Menus.lua:476-478` stores food selection as three separate keys in `Quiver.db.char.menuSelections`:
```lua
Quiver.db.char.menuSelections["food"]       = food.name
Quiver.db.char.menuSelections["foodID"]     = food.itemID
Quiver.db.char.menuSelections["foodIsBuff"] = food.isPetBuff == true
```
While `menuSelections` is a flat string-keyed table, having "food", "foodID", and "foodIsBuff" as sibling keys alongside menu names like "aspects", "pet", "traps", "tracking" is fragile — a rename or the addition of a menu named "foodID" would collide. These three keys should be a nested table `menuSelections.food = { name, itemID, isPetBuff }`.

---

## 4. UI Layer: Sphere and Menus Interaction

### Sphere owns orbit buttons; Menus owns menu buttons

`UI/Sphere.lua:SetupMenuButtons()` creates the orbit buttons (`QuiverBtn_aspects`, `QuiverBtn_pet`, `QuiverBtn_traps`, `QuiverBtn_tracking`, `QuiverBtn_food`). `UI/Menus.lua` creates the expanding menu-item buttons and positions them relative to the orbit buttons via `_G["QuiverBtn_*"]` global name lookups.

This split means: **Sphere creates the trigger; Menus later overwrites the trigger's `PostClick` script and `SetNormalTexture`** in `PopulateMenu()` (`UI/Menus.lua:315-322`). The initial `PostClick` set in `SetupMenuButtons()` (`UI/Sphere.lua:180-212`) is a placeholder that gets replaced during `Menus:Initialize()` → `RebuildAll()` → `PopulateMenu()`. This works because `Sphere:Initialize()` is called before `Menus:Initialize()` in `Core:Initialize()`, but the intent is non-obvious and the Sphere-side PostClick handlers for non-food buttons are entirely superseded.

### `stings` menu is defined nowhere

`UI/Sphere.lua:SetupMenuButtons()` does **not** create a `QuiverBtn_stings` orbit button. `UI/Menus.lua:Initialize()` does **not** define a `stings` menu entry. Stings has a data module (`Modules/Stings.lua`) and a sting bar on the sphere, but there is no menu for casting stings. This is likely an unfinished feature.

### Food picker: architectural concerns

The food picker uses a pool of 5 pre-created `MakeFoodButton()` frames (created at `Menus:Initialize()` time, `UI/Menus.lua:718`) that are shown/hidden via `SetAlpha` and `EnableMouse`. This approach is consistent with the menu button strategy elsewhere and is correct.

**However, there is an asymmetry in food button creation versus the orbit button.** The orbit `QuiverBtn_food` is a `SecureActionButtonTemplate` button created in `Sphere:SetupMenuButtons()`. The food picker buttons are also `SecureActionButtonTemplate` buttons created in `MakeFoodButton()`. Both use `type2`/`macrotext2` for right-click. This is correct.

---

## 5. WoW TBC Classic API Usage

### `GetInventoryItemCount` with "player" unit: valid

`Modules/Ammo.lua:25`:
```lua
local ammoSlot = GetInventorySlotInfo("AmmoSlot")
self.count = GetInventoryItemCount("player", ammoSlot) or 0
```
`GetInventoryItemCount(unit, slotId)` is valid in TBC Classic. `GetInventorySlotInfo("AmmoSlot")` returns slot 0 for the ammo pouch. This is correct.

### `UnitBuff` signature in TBC Classic

`Modules/Aspects.lua:50`:
```lua
local name = UnitBuff("player", i)
```
In TBC Classic, `UnitBuff(unit, index)` returns multiple values: `name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable`. Capturing only `name` is fine for the aspect check.

### `UnitDebuff` in Stings: correct usage

`Modules/Stings.lua:35`:
```lua
local name, _, _, _, _, duration, expirationTime, unitCaster = UnitDebuff("target", i)
```
The TBC Classic `UnitDebuff` signature matches this. `unitCaster` comparison to `"player"` is correct.

### `GetSpellCooldown` by name: works but rank-sensitive

`Modules/Traps.lua:27` and `UI/Menus.lua:425`:
```lua
local start, duration = GetSpellCooldown(trap.name)
```
`GetSpellCooldown` accepts spell name in TBC Classic and picks the highest known rank. This is correct behavior.

### `C_Container.GetContainerItemInfo` — Dragonflight API used in TBC

`Modules/Pet.lua:67` and `UI/Menus.lua:557`:
```lua
local info = C_Container.GetContainerItemInfo(bag, slot)
```
**This is a Dragonflight-era API.** In TBC Classic (Interface 20504), the correct API is:
```lua
GetContainerItemInfo(bag, slot)
-- returns: texture, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBattlePay
```
`C_Container` was not available until Shadowlands/Dragonflight. However, Blizzard backported `C_Container` to all Classic clients at some point, so this **may work** on the current TBC Anniversary build depending on the patch level. If it works it works, but it is fragile: a patch could remove the backport.

The code accesses `info.itemID`, `info.stackCount`, `info.iconFileID` — these match the Dragonflight `C_Container.GetContainerItemInfo()` return table. If the API isn't available, `C_Container` would be nil and this would error at the module level rather than gracefully degrade.

### `GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)` returning spell ID

`UI/Menus.lua:41`:
```lua
local spellType, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
```
In TBC Classic, `GetSpellBookItemInfo` returns `(type, spellID)`. This is correct.

### `GetSpellBookItemName` — non-existent API

`UI/Menus.lua:43`:
```lua
local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
```
**`GetSpellBookItemName` does not exist in TBC Classic.** The correct function is `GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)` which already returns the ID; to get the name you call `GetSpellInfo(spellID)`. In practice this means `knownSpellCache` will **never be populated** — `name` will always be nil — so `IsSpellKnown()` always returns false, menu buttons for all spells are hidden, and the menus appear empty.

Wait — looking more carefully: `GetSpellBookItemName` may actually exist as an alias in some WoW Classic builds. Let me note this as a **risk** requiring verification: if the function is unavailable, no menus build at all.

### `GetPetFoodTypes()` availability

`Modules/Pet.lua:58`:
```lua
for _, ft in ipairs({GetPetFoodTypes()}) do
```
`GetPetFoodTypes()` exists in TBC Classic and returns the diet strings for the current pet. This is correct.

### `GetPetHappiness()` deprecation

`Modules/Pet.lua:33`:
```lua
self.happiness = GetPetHappiness()
```
`GetPetHappiness()` was deprecated in Cataclysm and removed in later versions. In TBC Classic Anniversary (20504) it is still present and valid. No issue.

### `GetTrackingTexture()` — correct for TBC

`Modules/Tracking.lua:33`:
```lua
local texture = GetTrackingTexture()
```
Valid for TBC Classic. Returns the icon path string or nil. Correct usage.

### `GetCVarBool("ActionButtonUseKeyDown")` — safe but called at frame creation time

`UI/Sphere.lua:20` and `UI/Menus.lua:89`, `111`:
```lua
local keydown = GetCVarBool("ActionButtonUseKeyDown")
b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")
```
This is read once at initialization and never updated. If the player changes the CVar after login, the buttons won't update. Not a serious issue for most users.

---

## 6. Lua Correctness

### Nil dereference risk: `Quiver.UI.Sphere:UpdateAmmoDisplay()` called before Sphere init

`Modules/Ammo.lua:16-18`:
```lua
function Ammo:Enable()
    Quiver:RegisterEvent("BAG_UPDATE", function() self:UpdateCount() end)
    ...
    self:UpdateCount()
```
`UpdateCount()` at line 34 calls `Quiver.UI.Sphere:UpdateAmmoDisplay()`. This is called in `Core:Enable()`, which runs after `Core:Initialize()` where `Sphere:Initialize()` is called. So `self.frame` and `self.ammoText` should exist. Safe.

### Nil dereference risk: `Traps:UpdateCooldowns()` called before `Menus:Initialize()`

`Modules/Traps.lua:30`:
```lua
Quiver.UI.Menus:UpdateTrapCooldowns()
```
This is called from `Traps:Enable()` which runs in `Core:Enable()`. `Menus:Initialize()` is called in `Core:Initialize()`, which runs before `Core:Enable()`. By the time `Enable()` runs, `Menus.menus` exists. However, `Menus:UpdateTrapCooldowns()` accesses `self.menus.traps` (line 419) — if for any reason `Menus:Initialize()` failed or wasn't called, this would throw. Fragile but not a current bug.

### Boolean/nil confusion: `Pet.exists = UnitExists("pet")`

`Modules/Pet.lua:31`:
```lua
self.exists = UnitExists("pet")
```
`UnitExists()` returns 1 (number) or nil. Code throughout the addon treats `self.exists` as a boolean, e.g. `if Quiver.Modules.Pet.exists then`. Lua's truthiness means nil is false and 1 is true — this works. But it's not idiomatic; `self.exists = UnitExists("pet") and true or false` would be cleaner.

### `food.isPetBuff == true` comparison is redundant but correct

`Data/PetFoods.lua` stores `petBuffIDs[id] = true`. `Pet.lua:71` checks `isPetBuff = petBuffIDs[info.itemID] == true`. Since the stored value is always `true` (a boolean), `== true` is a no-op comparison but not incorrect. `byName[name].isPetBuff = isPetBuff` then stores this boolean. Later, `food.isPetBuff == true` checks it strictly. Fine.

### Closure capture in `PopulateMenu` loop

`UI/Menus.lua:202`:
```lua
local capturedEntry = entry
b:SetScript("PostClick", function(_, button)
    if button == "LeftButton" then
        Menus:SelectEntry(menu, capturedEntry)
    end
end)
```
`capturedEntry` is a new local per iteration — correct closure capture. `menu` is captured from the outer function argument, also correct. No bug here.

### `GetSpellInfo(castTarget)` when `castTarget` is nil

`UI/Menus.lua:175-178`:
```lua
local castTarget = spellId or entry.spell
if not icon and castTarget then
    local _, _, spellIcon = GetSpellInfo(castTarget)
    icon = spellIcon
end
```
The `castTarget` nil guard is present. However `entry.spell` can be nil for entries without a spell (though currently no such entries exist in the menu definitions). Safe as written.

### `table.sort` comparator: `isPetBuff` truthy/falsy issue

`Modules/Pet.lua:95-100`:
```lua
table.sort(sorted, function(a, b)
    local ap = (a.isPetBuff and 0 or 1)
    local bp = (b.isPetBuff and 0 or 1)
    if ap ~= bp then return ap < bp end
    return a.itemLevel > b.itemLevel
end)
```
`a.isPetBuff` is a boolean (`true` or `false`, explicitly set at line 82 with `isPetBuff = isPetBuff` where `isPetBuff` came from `petBuffIDs[id] == true`). Since `false and 0 or 1` evaluates to 1 and `true and 0 or 1` evaluates to 0, the sort is correct. But relying on the ternary trick with boolean `false` is fragile: if `isPetBuff` were ever nil, `nil and 0 or 1` also evaluates to 1 (not pet buff) which is correct. Accidentally safe.

### `Pet:UpdateState` sound check uses wrong db key

`Modules/Pet.lua:42`:
```lua
if self.happiness == 1 and Quiver.db.profile.sounds.ammoLow then
```
This checks `sounds.ammoLow` instead of `sounds.petUnhappy`. The correct key (`petUnhappy`) is defined in `Core/Core.lua:19`. This is a copy-paste bug — pet unhappy sound respects the ammo-low sound toggle instead of its own toggle.

### `Ammo:OnAmmoLow()` fires on every update when below threshold

`Modules/Ammo.lua:36-38`:
```lua
if self.count < Quiver.db.profile.ammoWarnThreshold then
    self:OnAmmoLow()
end
```
`OnAmmoLow()` is called every time `UpdateCount()` runs and ammo is below the threshold — on every `BAG_UPDATE` and `PLAYER_ENTERING_WORLD` event. Since the sound is commented out this causes no audible spam, but the intent was probably to fire once when crossing the threshold, not continuously while below it. A `wasLow` flag like `Mana.lua` uses would fix this.

### `Aspects:Cast` uses `CastSpellByName`

`Modules/Aspects.lua:72`:
```lua
function Aspects:Cast(aspectName)
    CastSpellByName(aspectName)
end
```
`CastSpellByName` is not a secure API — it cannot be called from a macro-independent context during combat. However, this function appears to be unused; aspects are cast via the `SecureActionButtonTemplate` `type2`/`macrotext2` mechanism in the menu buttons. Dead code, but if called, it would taint the UI in combat.

The same issue applies to `Pet:CallPet()`, `Pet:DismissPet()`, etc. (`Modules/Pet.lua:107-110`), `Stings:Cast()` (`Modules/Stings.lua:57`), `Traps:Cast()` (`Modules/Traps.lua:40`), and `Tracking:Cast()` (`Modules/Tracking.lua:38-41`). All use `CastSpellByName` and appear unused externally. They are safe as dead code but should either be removed or called only from `PostClick`/`OnClick` handlers.

---

## 7. SecureActionButtonTemplate Usage

### Correct pattern: `type2`/`macrotext2` for right-click

All cast buttons use `type2` + `macrotext2` for right-click spells, which is the correct pattern for `SecureActionButtonTemplate`. Left-click (`type`/`macrotext`) is used for the sphere's configurable spell. This is idiomatic.

### `PostClick` used for all non-combat UI actions

Menu toggle (`Toggle`, `HideAll`, `ToggleFoodPicker`) and `SelectEntry`/`SelectFood` are all invoked from `PostClick` handlers, never from `PreClick` or the secure handler itself. This is correct: `PostClick` fires after the secure action completes and is not subject to combat lockdown restrictions for non-secure operations.

### `SetAttribute` in `PostClick` — the deferred ticker

`UI/Menus.lua:17-28` comments explain this:
> "Deferred attribute application: SetAttribute on secure frames from PostClick (after a secure action fired) can be silently blocked in TBC Classic."

The `selectionTicker` exists to apply `SetAttribute` calls on the next frame after a `PostClick`, outside any secure execution chain. This is a known workaround for TBC Classic's stricter secure handling. The approach is sound.

**However:** `Menus:SelectEntry()` (`UI/Menus.lua:350-376`) calls `UpdateTriggerReadiness(menu)` and then sets `pendingSelectionMenu = menu`. `UpdateTriggerReadiness` only touches `SetAlpha` and `SetScript` (non-protected operations). `pendingSelectionMenu` queues the `SetAttribute` call (`ApplySelectionToTrigger`). This split is intentional and correct.

**Also:** `Menus:SelectEntry()` calls `triggerBtn:SetNormalTexture(icon)` at line 367 directly inside the function, not deferred. `SetNormalTexture` on a `SecureActionButtonTemplate` is a protected operation. **If `SelectEntry` is ever called from within a secure callback chain (not just PostClick), this would silently fail in combat.** Currently it's only called from `PostClick`, so it works — but it's worth being aware of.

### `SetAttribute` calls outside combat in `RebuildAll`

`Menus:RebuildAll()` is guarded by `if InCombatLockdown() then return end`. All `SetAttribute` calls within `PopulateMenu` and `ApplySelectionToTrigger` are therefore safe. Correct.

### Orbit button for food: left-click action conflict

`UI/Sphere.lua:159-161` (food orbit button setup):
```lua
b:SetAttribute("type2", "macro")
b:SetAttribute("macrotext2", "")
```
A blank `type2`/`macrotext2` is set here as a no-op right-click placeholder. Then `Menus:RebuildFoodPicker()` and `Menus:SelectFood()` overwrite `type2`/`macrotext2` with the feed macro. This two-phase setup is correct.

**However**, `SetupMenuButtons` does not set `type` or `macrotext` at all for the food button, leaving the left-click secure action undefined. Left-click fires the `PostClick` → `ToggleFoodPicker()`. No secure action fires on left-click, which is correct — the food picker is a pure UI action.

---

## 8. Food Picker Bug: Root Cause Analysis

**Reported symptom:** Left-clicking a food in the picker doesn't correctly update the orbit button icon.

### The call chain

1. User left-clicks a food picker button.
2. `SecureActionButtonTemplate` fires — no `type` attribute set, so no secure action.
3. `PostClick` fires: `Menus:SelectFood(capturedFood)` (`UI/Menus.lua:527-530`).
4. `SelectFood()` (`UI/Menus.lua:474-503`):
   - Writes `Quiver.db.char.menuSelections["food"]` etc.
   - Calls `btn:SetNormalTexture(icon)` and `btn:SetPushedTexture(icon)`.
   - Calls `btn:SetAlpha(1.0)`.
   - Calls `btn:SetAttribute("type2", ...)` and `btn:SetAttribute("macrotext2", ...)`.
   - Calls `self:HideFoodPicker()`.

### Identified issues

**Issue A: `SelectFood` sets `type2`/`macrotext2` attributes from a PostClick context.**

`UI/Menus.lua:488-489`:
```lua
btn:SetAttribute("type2", "macro")
btn:SetAttribute("macrotext2", macro)
```
`btn` here is `QuiverBtn_food`, which is a `SecureActionButtonTemplate` frame. **Calling `SetAttribute` on a secure frame from within a `PostClick` handler is the exact scenario the `selectionTicker` deferral was designed to handle for the menu buttons.** `SelectFood` does not use the deferral mechanism — it calls `SetAttribute` directly. In TBC Classic, this call may be silently dropped if invoked within the secure execution context of a prior click event. The icon and tooltip update (non-protected operations) succeed, but the attribute write fails silently, leaving the orbit button's right-click macro stale.

**Issue B: `SetNormalTexture` inside `SelectFood` may be the one that succeeds, making the bug intermittent.**

`btn:SetNormalTexture(icon)` at line 483 is not a protected operation on a `SecureActionButtonTemplate` — it sets the visual texture, not a secure attribute. This call should always succeed. So the **icon update works** but the **macro attribute update fails**. This would manifest as: icon changes correctly, but right-clicking the orbit button after selecting food uses the old macro (or no macro).

If the report is "icon doesn't update," re-examine whether `SelectFood` is actually being called. Add a `print` or `UIErrorsFrame:AddMessage` to confirm.

**Issue C: `capturedFood` in `RefreshFoodPicker` — stale closure on re-layout.**

`UI/Menus.lua:527`:
```lua
local capturedFood = food
b:SetScript("PostClick", function(_, button)
    if button == "LeftButton" then
        Menus:SelectFood(capturedFood)
    end
end)
```
`capturedFood` is captured per-iteration of the `RefreshFoodPicker` loop. This is correct **for that call to `RefreshFoodPicker`**. However, `RefreshFoodPicker` is called both from `ToggleFoodPicker` (when opening) and from `BAG_UPDATE_DELAYED`. If bags update while the picker is open, `RefreshFoodPicker` runs again, re-binding `PostClick` with the updated `capturedFood`. This is correct behavior — the food count updates and the closure is fresh.

**Issue D: `RebuildFoodPicker` restores icon from `GetItemInfo` — returns nil when item cache is cold.**

`UI/Menus.lua:619`:
```lua
local _, _, _, _, _, _, _, _, _, savedIcon = GetItemInfo(savedID or savedName)
```
`GetItemInfo` returns nil for all values when the item is not in the client cache. If the addon loads and the item hasn't been seen yet this session, `savedIcon` is nil, and `btn:SetNormalTexture(icon)` is skipped (the `if icon then` guard at line 624). The orbit button will show a blank/previous icon until `BAG_UPDATE_DELAYED` fires (which calls `RefreshFoodPicker` → iterates bags → `GetItemInfo` on items physically in bags is more likely to succeed). This causes a cosmetic flash on login, not a persistent bug.

**Issue E (most likely the primary bug): `SelectFood` is called from a food picker `PostClick`, but the food picker buttons are `SecureActionButtonTemplate` frames.**

`MakeFoodButton()` creates a `SecureActionButtonTemplate` button (`UI/Menus.lua:104`). When the user left-clicks it, the secure system processes the click. Even though no `type` attribute is set (line 518: `b:SetAttribute("type", nil)`), the button still fires through the secure execution path. `PostClick` then fires `Menus:SelectFood(capturedFood)`.

Inside `SelectFood`, `btn:SetAttribute("type2", "macro")` is called on `QuiverBtn_food`, which is **a different** `SecureActionButtonTemplate` button. In TBC Classic, **writing attributes to any protected frame from within a PostClick callback (after a secure action, even a no-op one)** can be blocked. The behaviour depends on whether the secure system considers itself "in a secure execution context" at the time.

**Recommended fix for Issue A/E:**

Apply the same deferral pattern used for menu `SelectEntry`:
```lua
-- In SelectFood, after updating non-secure properties:
pendingFoodSelection = food   -- new module-local
self:HideFoodPicker()

-- In selectionTicker OnUpdate:
if pendingFoodSelection and not InCombatLockdown() then
    local food = pendingFoodSelection
    pendingFoodSelection = nil
    local btn = _G["QuiverBtn_food"]
    if btn then
        local macro = food.isPetBuff
            and ("/use " .. food.name)
            or  ("/cast Feed Pet\n/use " .. food.name)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", macro)
    end
end
```
Icon, tooltip, and `SetAlpha` can remain in `SelectFood` since they are unprotected. Only the `SetAttribute` calls need deferral.

---

## 9. Additional Minor Issues

### `UI/Menus.lua:587` — `RebuildFoodPicker` exits early if pool is empty

```lua
function Menus:RebuildFoodPicker()
    if #foodPickerButtons == 0 then return end
```
The food picker button pool (`foodPickerButtons`) is populated in `Menus:Initialize()` (line 718). `RebuildFoodPicker` is called from `Pet:UpdateState()` (`Modules/Pet.lua:39`), which can fire from `PLAYER_ENTERING_WORLD` via `Pet:Enable()` → `Quiver:OnEnable()`. If `Pet:Enable()` fires before `Menus:Initialize()` completes, the pool is empty and the early return guards against a crash. However in the current init order this cannot happen: `Menus:Initialize()` is called in `Core:Initialize()`, and `Enable()` is only called from `Quiver:OnEnable()`, which runs after `OnInitialize()`. Safe.

### `UI/Sphere.lua:289` — ammo count always warns at 0

```lua
if count < Quiver.db.profile.ammoWarnThreshold then
    self.ammoText:SetTextColor(1, 0.2, 0.2)
```
`ammoWarnThreshold` defaults to 100 (`Core/Core.lua:8`). When no ammo pouch is equipped, `GetInventoryItemCount` returns 0, which is less than 100, so the ammo text turns red whenever a hunter has no ammo pouch equipped. Arguably correct but could be noisy for new characters. Consider: `count > 0 and count < threshold`.

### `UI/Menus.lua` — `UpdateTrapCooldowns` crashes if `triggerBtn.cdText` is nil

`UI/Menus.lua:455`:
```lua
triggerBtn.cdText:SetText(...)
```
`triggerBtn.cdText` is set in `Sphere:SetupMenuButtons()` for the traps button (`UI/Sphere.lua:169-175`). If somehow the trap orbit button does not have `cdText` (e.g., creation order issue or the button doesn't exist), this will throw a nil index error. An `if triggerBtn.cdText then` guard would make it defensive.

### `Quiver.toc` declares `SavedVariables: QuiverDB` but not `QuiverCharDB`

`Quiver.toc:7`:
```
## SavedVariables: QuiverDB
```
`AceDB-3.0` handles both `profile` and `char` scopes under the single `QuiverDB` saved variable. The `char` scope data is stored under `QuiverDB.char`. This is how AceDB works — no separate `QuiverCharDB` is needed. The `CLAUDE.md` mentions `QuiverCharDB` as a separate saved variable, but the implementation correctly uses one AceDB variable with a `char` key. No actual bug, but the documentation in `CLAUDE.md` is misleading.

### `Locales/enUS.lua` is dead code

`Quiver.L` is fully populated but never referenced by any module or UI file. All display strings are hardcoded inline. Either remove the locale file or actually use `Quiver.L.*` throughout.

---

## 10. Summary Table

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **High** | `UI/Menus.lua:488-489` | `SelectFood` calls `SetAttribute` directly from PostClick context — the root cause of the food picker icon/macro bug |
| 2 | **High** | `UI/Menus.lua:43` | `GetSpellBookItemName` may not exist in TBC Classic — if absent, `knownSpellCache` is never populated and all menus are empty |
| 3 | **Medium** | `Modules/Pet.lua:42` | Checks `sounds.ammoLow` instead of `sounds.petUnhappy` — pet unhappy sound uses wrong config toggle |
| 4 | **Medium** | `Modules/Ammo.lua:36-38` | `OnAmmoLow` fires on every update while below threshold, not just on threshold crossing |
| 5 | **Medium** | `UI/Menus.lua:728-736` | Trap cooldown `OnUpdate` ticker runs every frame unconditionally, not gated on menu visibility |
| 6 | **Medium** | `UI/Menus.lua:22-28` | `selectionTicker` `OnUpdate` runs every frame for entire session |
| 7 | **Low** | `Modules/Pet.lua:67`, `UI/Menus.lua:557` | `C_Container` API used — may not be available in all TBC Classic Anniversary builds |
| 8 | **Low** | `Modules/Tracking.lua:40` | `lastTracking` written but never read — dead state |
| 9 | **Low** | `Core/Core.lua:26` | `lastAspect` declared in defaults but never written — feature unimplemented |
| 10 | **Low** | `UI/Menus.lua:476-478` | Food selection stored as three flat keys in `menuSelections` — fragile naming scheme |
| 11 | **Low** | `UI/Sphere.lua:289` | Ammo text always red when no ammo equipped (0 < 100) |
| 12 | **Low** | `UI/Menus.lua:455` | `triggerBtn.cdText:SetText` without nil guard |
| 13 | **Info** | All modules | `CastSpellByName` helper methods are dead code that would taint UI if called in combat |
| 14 | **Info** | `Locales/enUS.lua` | Locale table completely unused |
| 15 | **Info** | `Aspects.lua` + `Mana.lua` | Both add permanent OnUpdate pollers in addition to event handlers |
| 16 | **Info** | All modules | `PLAYER_ENTERING_WORLD` registered 7+ times across modules — harmless but noisy |
