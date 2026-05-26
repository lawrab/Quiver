# Quiver — WoW TBC Anniversary Hunter Addon

## What We're Building

**Quiver** is a hunter class mod for WoW TBC Classic Anniversary realms, modeled after the Necrosis warlock addon. The core concept is a circular **sphere UI** that sits on screen as a central hub, giving hunters one-click access to all class-specific mechanics.

Necrosis reference: https://github.com/CLKRUN/Necrosis-Classic

## Design Concept

A draggable central orb (the "sphere") whose color/texture reflects the active Aspect. Clicking or hovering expands radial menus for each hunter mechanic category. Small status indicators float around the sphere showing ammo count, pet happiness, and active cooldowns.

### Sphere Sections (radial menus around the orb)

| Section | What it does |
|---|---|
| **Ammo** | Shows arrow/bullet count as a number on the sphere. Turns red when low. Click to open ammo bag slot. |
| **Aspects** | Menu to instantly switch aspects. Sphere color reflects active aspect (green=Hawk, blue=Viper, yellow=Cheetah, etc.) |
| **Pet** | Call, Dismiss, Revive, Mend Pet. Pet happiness shown as color indicator (green/yellow/red). |
| **Stings** | One-click cast for Serpent/Viper/Scorpid/Wyvern Sting. Shows active sting duration on current target. |
| **Traps** | Frost, Freezing, Immolation, Explosive, Snake trap quick-cast. Shows trap cooldown timer. |
| **Tracking** | Switch between tracking types (Beasts, Humanoids, Demons, Undead, Giants, Elementals). |
| **Timers** | Shows Rapid Fire, Bestial Wrath cooldowns. Serpent Sting duration bar. Kill Command proc alert. |

### Extra features
- **Hunter's Mark** shortcut on sphere click
- **Feign Death** quick button
- **Misdirection** quick button
- Sound alerts: ammo < 100, pet unhappy, Bestial Wrath proc, Kill Command proc
- DoT timer for Serpent Sting on current target

## TBC Hunter Mechanics Reference

### Aspects (mutually exclusive, one active at a time)
- Aspect of the Hawk — main DPS aspect (+AP)
- Aspect of the Viper — mana regen (use when OOM)
- Aspect of the Cheetah — speed (can't be hit in combat)
- Aspect of the Pack — group speed buff
- Aspect of the Wild — nature resistance
- Aspect of the Monkey — increased dodge
- Aspect of the Dragonhawk — combines Hawk + Monkey (lvl 68)

### Traps (can now be placed in combat in TBC)
- Frost Trap — AoE slow on ground
- Freezing Trap — CC single target (breaks on damage)
- Immolation Trap — fire damage when triggered
- Explosive Trap — AoE fire damage
- Snake Trap — summons venomous snakes

### Stings (mutually exclusive on target, one sting at a time)
- Serpent Sting — nature DoT (main PvE sting)
- Viper Sting — mana drain (PvP/caster fights)
- Scorpid Sting — reduces chance to hit (debuff)
- Wyvern Sting — sleep + nature DoT (Survival talent)

### Key Resources/Cooldowns to Track
- **Ammo** — arrows or bullets, finite, can run out mid-fight (critical!)
- **Pet happiness** — unhappy pets deal reduced damage; needs feeding
- **Mend Pet** — channeled HoT on pet
- **Rapid Fire** — 3-min cooldown burst
- **Bestial Wrath** — BM cooldown (you and pet go berserk)
- **Kill Command** — instant proc when pet crits
- **Serpent Sting duration** — keep refreshed on target
- **Hunter's Mark** — mark target for +AP vs target

## Tech Stack

- **Language**: Lua (WoW API)
- **Interface**: TBC Classic Anniversary — Interface version `20504`
- **Library pattern**: Ace3 framework (AceAddon-3.0, AceEvent-3.0, AceDB-3.0, AceGUI-3.0)
- **Saved Variables**: `QuiverDB` (account-wide), `QuiverCharDB` (per-character)

## File Structure

```
Quiver/
├── Quiver.toc          # Addon manifest (interface version, load order)
├── Quiver.lua          # Entry point, addon registration
├── CLAUDE.md           # This file
├── Core/
│   └── Core.lua        # Addon init, defaults, event registration
├── UI/
│   ├── Sphere.lua      # Central sphere frame, drag, color updates
│   └── Menus.lua       # Radial/expandable menus for each section
├── Modules/
│   ├── Ammo.lua        # Ammo count tracking (bag scan)
│   ├── Aspects.lua     # Aspect detection + quick-cast
│   ├── Pet.lua         # Pet state, happiness, call/dismiss/mend
│   ├── Stings.lua      # Active sting tracking on target
│   ├── Traps.lua       # Trap cooldown tracking
│   └── Tracking.lua    # Current tracking type
├── Libs/               # Ace3 and other embedded libraries
├── Locales/
│   └── enUS.lua        # English strings
└── Media/
    └── Sounds/         # Sound files for alerts
```

## WoW Addon Development Notes

### Key WoW API patterns for this addon
- `UnitClass("player")` — verify player is a hunter before showing UI
- `GetInventoryItemCount(0, 0)` / bag scanning for ammo count
- `GetShapeshiftForm()` — used for Aspects (aspects are shapeshifts in TBC)
- `UnitDebuff("target", ...)` — check active stings on target
- `GetSpellCooldown(spellName)` — trap/cooldown timers
- `UnitAffectingCombat("player")` — combat state
- `GetPetHappiness()` — returns 1 (unhappy), 2 (content), 3 (happy)
- Events: `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, `BAG_UPDATE`, `UNIT_PET`

### Ace3 addon pattern
```lua
local Quiver = LibStub("AceAddon-3.0"):NewAddon("Quiver", "AceEvent-3.0")
function Quiver:OnInitialize() ... end
function Quiver:OnEnable() ... end
```

### Saved variables defaults
Config stored in `QuiverDB` via AceDB-3.0. Per-character state (like last aspect) in `QuiverCharDB`.

### Button visual state gotchas (hard-won)

**NormalTexture and PushedTexture are mutually exclusive.** When a button is pressed, WoW renders only the PushedTexture — NormalTexture is hidden entirely. Always set both to the same icon so the icon stays visible during a click. This applies to every button showing an item/spell icon.

**Pushed state gets stuck when `EnableMouse(false)` is called mid-press.** WoW tracks pushed state via mouse events. If you call `EnableMouse(false)` while the mouse button is still physically held (common with `RegisterForClicks("AnyDown")` — the click fires on press, before the user releases), the button never receives `OnMouseUp` and stays stuck in PUSHED state. The next time the button is shown it will still be visually depressed. Fix: call `b:SetButtonState("NORMAL")` before hiding/disabling:
```lua
b:SetButtonState("NORMAL")
b:SetAlpha(0)
b:EnableMouse(false)
```

**`SetBackdrop` requires `"BackdropTemplate"` in the frame template string on Anniversary clients.** TBC Classic Anniversary runs on a newer client than original 2.5 — `SetBackdrop` was moved to a mixin. Always create backdrop frames as `CreateFrame("Frame", ..., parent, "BackdropTemplate")` or you get a nil-method error.

**`SetNormalTexture`/`SetPushedTexture` don't render numeric fileIDs on `SecureActionButtonTemplate` buttons that are children of another secure frame.** Use `CreateTexture(nil, "OVERLAY")` instead — OVERLAY layer textures accept numeric fileIDs and are always visible regardless of button press state. See `SetFoodOrbitIcon` in `UI/Menus.lua` for the pattern.

## WoW API Reference

**wow-api-mcp** is configured in `.mcp.json` — use it to look up WoW API functions, events, enums, and widget methods (8000+ entries with full signatures). Falls back to wowpedia.org via web search for anything not covered.
