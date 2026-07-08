-- Expandable menus that appear around the sphere when a section button is clicked.
-- Menus filter to known spells only and rebuild on SPELLS_CHANGED.
--
-- SecureActionButtonTemplate buttons must be children of UIParent; we
-- position and show/hide them individually rather than via a container frame.

local Menus = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Menus = Menus

local BUTTON_SIZE = 28
local BUTTON_SPACING = 34
local activeMenu = nil
local foodPickerOpen = false
local foodPickerButtons = {}

-- Pre-built sub-second countdown strings; avoids string.format allocation in the
-- 0.1 s ticker hot path. Index by math.floor(remaining * 10) where 0 ≤ remaining < 1.
local TENTHS_STR = {}
for i = 0, 9 do TENTHS_STR[i] = "0." .. i end

-- Sentinel used to distinguish "never initialised" from nil (no selection).
-- Ensures UpdateTriggerReadiness always binds OnEnter/OnLeave on the first call.
local UNSET_SELECTION = {}

-- Trap cooldown ticker.
-- When the trap menu is open: 0.1 s for smooth expansion-button text.
-- When menu is closed but a trap is cooling: 0.5 s for the trigger button only.
local cdTickerElapsed = 0
local cdTicker = CreateFrame("Frame")
cdTicker:Hide()
cdTicker:SetScript("OnUpdate", function(_, dt)
    cdTickerElapsed = cdTickerElapsed + dt
    local interval = (activeMenu == "traps") and 0.1 or 0.5
    if cdTickerElapsed >= interval then
        cdTickerElapsed = 0
        Quiver.UI.Menus:UpdateTrapCooldowns()
    end
end)

-- Deferred attribute application: SetAttribute on secure frames from PostClick
-- (after a secure action fired) can be silently blocked in TBC Classic.
-- We write the pending menu here and apply it on the very next OnUpdate frame.
local bwMacroPending = false  -- UpdateBWMacro was requested during combat; flush on PLAYER_REGEN_ENABLED
local pendingSelectionMenu = nil
local selectionTicker = CreateFrame("Frame")
selectionTicker:Hide()   -- only active while a deferred attribute write is pending
selectionTicker:SetScript("OnUpdate", function()
    if pendingSelectionMenu and not InCombatLockdown() then
        local m = pendingSelectionMenu
        pendingSelectionMenu = nil
        selectionTicker:Hide()
        Quiver.UI.Menus:ApplySelectionToTrigger(m)
    end
end)

-- Maps spell name → numeric spell ID (or true if ID unavailable) from spellbook scan.
-- We prefer spell IDs in secure attributes; they cast unambiguously regardless of rank.
-- Falls back to spell name string when GetSpellBookItemInfo doesn't return an ID.
local knownSpellCache = {}

local function RefreshSpellCache()
    wipe(knownSpellCache)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for slot = offset + 1, offset + count do
            local spellType, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
            local _, subtext = GetSpellInfo(spellID or GetSpellBookItemName(slot, BOOKTYPE_SPELL) or "")
            if spellType == "SPELL" and subtext ~= "Passive" then
                local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
                if name then
                    -- store ID when available; true otherwise (just marks as known)
                    knownSpellCache[name] = spellID or true
                    if name:match("^Call ") then
                        knownSpellCache["Call Pet"] = spellID or true
                    end
                end
            end
        end
    end
end

local function IsSpellKnown(spellName)
    return knownSpellCache[spellName] ~= nil
end

-- Returns the numeric spell ID if available, nil if only name is known.
local function GetSpellId(spellName)
    local v = knownSpellCache[spellName]
    return type(v) == "number" and v or nil
end

-- ── Button creation ───────────────────────────────────────────────────────────

-- Creates a blank action button with fixed properties only (size, strata,
-- blocker). Spell-specific attributes, icons, and scripts are applied later
-- in PopulateMenu so the same frame can be reconfigured on every rebuild
-- instead of being abandoned and replaced (which leaks C-side WoW frames).
local function CreateBlankButton()
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b:SetWidth(BUTTON_SIZE)
    b:SetHeight(BUTTON_SIZE)
    b:SetFrameStrata("DIALOG")
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")
    b:Hide()

    -- Non-secure blocker frame: sits on top of b when the menu is closed so
    -- right-clicks don't ghost-fire the hidden secure button's macro.
    -- Normal frames can be shown/hidden freely during combat lockdown;
    -- EnableMouse on a SecureActionButtonTemplate cannot.
    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetAllPoints(b)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(b:GetFrameLevel() + 1)
    blocker:EnableMouse(true)
    blocker:Hide()
    b.blocker = blocker

    return b
end

local function MakeFoodButton()
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b:SetWidth(BUTTON_SIZE)
    b:SetHeight(BUTTON_SIZE)
    b:SetFrameStrata("DIALOG")
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")
    local countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, 2)
    countText:SetTextColor(1, 1, 1)
    b.countText = countText
    b:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetAlpha(0)
    b:EnableMouse(false)
    b:Show()
    return b
end

-- ── Menu rebuild ──────────────────────────────────────────────────────────────

local function UpdateTriggerReadiness(menu)
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end

    -- Only rebind scripts when the selection actually changes; SetScript allocates
    -- a closure every call so skipping identical-state rebinds reduces GC pressure.
    local nowSelected = menu.selected
    local nowOther    = menu.otherSelected
    if nowSelected == menu._lastSelected and nowOther == menu._lastOtherSelected then
        -- alpha may still need syncing even without a script change
        triggerBtn:SetAlpha(nowSelected and 1.0 or 0.6)
        return
    end
    menu._lastSelected      = nowSelected
    menu._lastOtherSelected = nowOther

    local section = menu.displayName
    if nowSelected then
        triggerBtn:SetAlpha(1.0)
        local spellName = nowSelected.spell or ""
        local rightClickLine
        local swapTip
        if nowOther and nowOther.spell then
            local selShort   = spellName:match("of the (.+)") or spellName
            local otherShort = nowOther.spell:match("of the (.+)") or nowOther.spell
            rightClickLine = "Right-click: " .. selShort .. " / " .. otherShort .. " (swap)"
        else
            rightClickLine = "Right-click: " .. spellName
            if menu.triggerName == "QuiverBtn_aspects" then
                swapTip = "Select a 2nd aspect to enable quick-swap"
            end
        end
        triggerBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(section)
            GameTooltip:AddLine("Left-click: open menu", 0.6, 0.6, 0.6)
            GameTooltip:AddLine(rightClickLine, 0.4, 1, 0.4)
            if swapTip then GameTooltip:AddLine(swapTip, 0.7, 0.7, 0.3) end
            GameTooltip:Show()
        end)
    else
        triggerBtn:SetAlpha(0.6)
        triggerBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(section)
            GameTooltip:AddLine("Left-click: open menu", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Right-click: no quick-cast set", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
    end
    triggerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function PopulateMenu(menu)
    -- Reset all pool buttons — reuse them rather than creating new frames.
    -- WoW cannot destroy frames; creating new ones on every RebuildAll leaks
    -- C-side frame memory that persists for the entire session.
    for _, b in ipairs(menu.pool) do
        b:Hide()
        if b.blocker then b.blocker:Hide() end
        b:ClearAllPoints()
        b.isFeedButton = nil
        b.cdSpell      = nil
    end
    wipe(menu.buttons)

    local poolIndex = 0
    for _, entry in ipairs(menu.entries) do
        if not entry.spell or IsSpellKnown(entry.spell) then
            poolIndex = poolIndex + 1
            local b = menu.pool[poolIndex]
            if not b then break end   -- pool sized to #entries; shouldn't happen

            -- Resolve icon and cast target for this entry
            local icon = entry.icon
            local spellId = entry.spell and GetSpellId(entry.spell)
            local castTarget = spellId or entry.spell
            if not icon and castTarget then
                local _, _, spellIcon = GetSpellInfo(castTarget)
                icon = spellIcon
            end

            -- Update icon textures; cache the normal texture object so
            -- UpdateTrapCooldowns never has to call GetNormalTexture() in a hot path.
            b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
            b:SetPushedTexture(icon or "Interface\\Buttons\\UI-Quickslot-Depress")
            b._normalTex = b:GetNormalTexture()

            -- Stings: left-click selects only (no accidental mid-fight cast).
            -- All other menus: left-click casts immediately so mid-combat selection
            -- works — SetAttribute is combat-locked so we can't update the trigger
            -- button's right-click macro until after the fight ends.
            local castOnLeft = menu.triggerName ~= "QuiverBtn_stings"
            if castTarget then
                local macroText
                if type(castTarget) == "number" then
                    local name = GetSpellInfo(castTarget)
                    macroText = name and ("/cast " .. name) or nil
                else
                    macroText = "/cast " .. castTarget
                end
                if macroText then
                    b:SetAttribute("type",       castOnLeft and "macro" or nil)
                    b:SetAttribute("macrotext",  castOnLeft and macroText or nil)
                    b:SetAttribute("type2",      "macro")
                    b:SetAttribute("macrotext2", macroText)
                else
                    b:SetAttribute("type",       nil)
                    b:SetAttribute("macrotext",  nil)
                    b:SetAttribute("type2",      nil)
                    b:SetAttribute("macrotext2", nil)
                end
            else
                b:SetAttribute("type",       nil)
                b:SetAttribute("macrotext",  nil)
                b:SetAttribute("type2",      nil)
                b:SetAttribute("macrotext2", nil)
            end

            -- Cooldown display — frames created once per pool slot on first use
            if entry.showCooldown and entry.spell then
                b.cdSpell = entry.spell
                if not b.cdFrame then
                    local cd = CreateFrame("Cooldown", nil, b)
                    cd:SetAllPoints(b)
                    cd.noOCC = true
                    cd.noCooldownCount = true
                    b.cdFrame = cd
                    local cdDim = b:CreateTexture(nil, "OVERLAY")
                    cdDim:SetAllPoints(b)
                    cdDim:SetTexture(0, 0, 0, 0.65)
                    cdDim:Hide()
                    b.cdDim = cdDim
                    local cdText = b:CreateFontString(nil, "OVERLAY")
                    cdText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                    cdText:SetPoint("CENTER", b, "CENTER", 0, 0)
                    cdText:SetJustifyH("CENTER")
                    cdText:SetTextColor(1, 1, 1)
                    cdText:Hide()
                    b.cdText = cdText
                end
            end

            -- Click and tooltip scripts (re-bound each rebuild; closures capture
            -- stable entry table references so this is correct and cheap)
            local capturedEntry = entry
            if entry.action == "feed" then
                b.isFeedButton = true
                b:SetScript("PostClick", function(_, button)
                    if button == "LeftButton" then
                        Menus:ToggleFoodPicker()
                    end
                end)
                b:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine("Feed Pet")
                    if Quiver.Modules.Pet.happiness == 3 then
                        GameTooltip:AddLine("Pet is already happy!", 0.2, 1.0, 0.2)
                    end
                    GameTooltip:AddLine("Left-click: open food picker", 0.6, 0.6, 0.6)
                    GameTooltip:AddLine("Right-click: cast Feed Pet", 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                local label = entry.label
                b:SetScript("PostClick", function(_, button)
                    if button == "LeftButton" then
                        Menus:SelectEntry(menu, capturedEntry)
                    end
                end)
                b:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine(label)
                    if castOnLeft then
                        GameTooltip:AddLine("Left-click: cast now", 0.6, 0.6, 0.6)
                    else
                        GameTooltip:AddLine("Left-click: select for quick-cast", 0.6, 0.6, 0.6)
                    end
                    GameTooltip:AddLine("Right-click: cast now", 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            table.insert(menu.buttons, b)
        end
    end

    -- Pre-position buttons at their open layout and show them invisible.
    -- SetPoint is only legal outside combat; PopulateMenu is always called
    -- outside combat (guarded by RebuildAll). Toggle/HideAll then only need
    -- SetAlpha, which is not protected and works during combat lockdown.
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end

    -- Recompute grow direction: side buttons expand away from the sphere center;
    -- top/bottom buttons (x-offset ≈ 0) fall back to screen-edge detection.
    local cx = triggerBtn:GetCenter()
    if cx then
        local sphere = Quiver.UI.Sphere.frame
        local sx = sphere and sphere:GetCenter()
        local dx = sx and (cx - sx) or 0
        if dx > 20 then
            menu.growLeft = false       -- button is right of sphere → expand right
        elseif dx < -20 then
            menu.growLeft = true        -- button is left of sphere → expand left
        else
            menu.growLeft = cx > UIParent:GetWidth() / 2  -- top/bottom: use screen edge
        end
    end

    for i, b in ipairs(menu.buttons) do
        b:ClearAllPoints()
        if menu.growLeft then
            b:SetPoint("RIGHT", triggerBtn, "LEFT", -6 - (i - 1) * BUTTON_SPACING, 0)
        else
            b:SetPoint("LEFT", triggerBtn, "RIGHT", 6 + (i - 1) * BUTTON_SPACING, 0)
        end
        b:Show()
        b:SetAlpha(0)
        b:SetFrameStrata("MEDIUM")
        if b.blocker then
            b.blocker:SetFrameStrata("MEDIUM")
            b.blocker:Show()
        end
    end

    if #menu.buttons == 0 then
        triggerBtn:SetAlpha(0.7)
        triggerBtn:SetNormalTexture("Interface\\AddOns\\Quiver\\Media\\lock")
        triggerBtn:SetPushedTexture("Interface\\AddOns\\Quiver\\Media\\lock")
        triggerBtn:SetScript("PostClick", nil)
        triggerBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(triggerBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("No spells learned yet", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        triggerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        -- Restore persisted selection if none loaded yet
        if not menu.selected then
            local menuName = menu.triggerName:match("QuiverBtn_(.+)")
            local saved = menuName and Quiver.db.char.menuSelections[menuName]
            if saved then
                for _, entry in ipairs(menu.entries) do
                    if entry.spell == saved then
                        menu.selected = entry
                        break
                    end
                end
            end
        end

        -- Validate stored selection — spell may have become unknown
        if menu.selected and menu.selected.spell and not IsSpellKnown(menu.selected.spell) then
            menu.selected = nil
        end

        -- Restore the aspects swap slot from saved state
        if menu.triggerName == "QuiverBtn_aspects" then
            if not menu.otherSelected then
                local menuName = menu.triggerName:match("QuiverBtn_(.+)")
                local savedOther = menuName and Quiver.db.char.menuSelections[menuName .. "_other"]
                if savedOther then
                    for _, entry in ipairs(menu.entries) do
                        if entry.spell == savedOther then
                            menu.otherSelected = entry
                            break
                        end
                    end
                end
            end
            if menu.otherSelected and menu.otherSelected.spell and not IsSpellKnown(menu.otherSelected.spell) then
                menu.otherSelected = nil
                local menuName = menu.triggerName:match("QuiverBtn_(.+)")
                if menuName then Quiver.db.char.menuSelections[menuName .. "_other"] = nil end
            end
        end

        -- Icon: prefer active selection, else fall back to hint
        local icon
        if menu.selected then
            local spellId = menu.selected.spell and GetSpellId(menu.selected.spell)
            local castTarget = spellId or menu.selected.spell
            icon = menu.selected.icon
            if not icon and castTarget then
                local _, _, si = GetSpellInfo(castTarget)
                icon = si
            end
        end
        if not icon then
            local hintId = GetSpellId(triggerBtn.spellHint or "")
            local hintTarget = hintId or triggerBtn.spellHint or ""
            local _, _, hi = GetSpellInfo(hintTarget)
            icon = hi
        end
        if not icon then
            for _, entry in ipairs(menu.entries) do
                if (not entry.spell or IsSpellKnown(entry.spell)) and entry.icon then
                    icon = entry.icon
                    break
                end
            end
        end
        if icon then
            triggerBtn:SetNormalTexture(icon)
            triggerBtn:SetPushedTexture(icon)
        end

        -- Apply right-click cast attribute for current selection
        Menus:ApplySelectionToTrigger(menu)

        local menuName = menu.triggerName:match("QuiverBtn_(.+)")
        triggerBtn:SetScript("PostClick", function(_, button)
            if button == "LeftButton" then
                Quiver.UI.Menus:Toggle(menuName)
            elseif button == "RightButton" then
                Quiver.UI.Menus:HideAll()
            end
        end)
        UpdateTriggerReadiness(menu)
    end

end

function Menus:GetKnownSpells()
    return knownSpellCache
end

function Menus:ApplySelectionToTrigger(menu)
    if InCombatLockdown() then return end
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end
    if menu.selected then
        local entry = menu.selected
        local spellId = entry.spell and GetSpellId(entry.spell)
        local castTarget = spellId or entry.spell
        local name = type(castTarget) == "number" and GetSpellInfo(castTarget) or castTarget
        if name then
            local macro
            local icon
            if menu.triggerName == "QuiverBtn_aspects" then
                -- Icon always tracks the CURRENTLY ACTIVE aspect (live state), not the selection.
                local current = Quiver.Modules.Aspects.current
                local iconName = (current and current.name) or name
                local _, _, aspectIcon = GetSpellInfo(iconName)
                icon = aspectIcon
                if menu.otherSelected then
                    local otherId   = menu.otherSelected.spell and GetSpellId(menu.otherSelected.spell)
                    local otherCast = otherId or menu.otherSelected.spell
                    local otherName = type(otherCast) == "number" and GetSpellInfo(otherCast) or otherCast
                    if otherName then
                        -- /castsequence advances through the list on each press and resets at
                        -- combat start.  ! prefix prevents toggling the aspect off if it happens
                        -- to already be active.  [stance:N] does NOT work for hunter aspects
                        -- (confirmed: aspects are not shapeshifts in TBC Anniversary's macro
                        -- system), so this sequence is the only in-combat swap mechanism.
                        macro = "/castsequence reset=combat !" .. otherName .. ", !" .. name
                        local badge = triggerBtn.swapBadge
                        if badge then
                            local badgeTarget = (current and current.name == name) and otherName or name
                            local _, _, badgeIcon = GetSpellInfo(badgeTarget)
                            if badgeIcon then
                                badge:SetTexture(badgeIcon)
                                badge:Show()
                            else
                                badge:Hide()
                            end
                        end
                    else
                        macro = "/cast " .. name
                        if triggerBtn.swapBadge then triggerBtn.swapBadge:Hide() end
                    end
                else
                    macro = "/cast " .. name
                    if triggerBtn.swapBadge then triggerBtn.swapBadge:Hide() end
                end
            else
                -- Non-aspects: icon shows the selected spell.
                icon = entry.icon
                if not icon then
                    local _, _, si = GetSpellInfo(castTarget)
                    icon = si
                end
                macro = "/cast " .. name
                if triggerBtn.swapBadge then triggerBtn.swapBadge:Hide() end
            end
            if icon then
                triggerBtn:SetNormalTexture(icon)
                triggerBtn:SetPushedTexture(icon)
            end
            triggerBtn:SetAttribute("type2", "macro")
            triggerBtn:SetAttribute("macrotext2", macro)
            return
        end
    end
    if triggerBtn and triggerBtn.swapBadge then triggerBtn.swapBadge:Hide() end
    triggerBtn:SetAttribute("type2", nil)
    triggerBtn:SetAttribute("macrotext2", nil)
end

function Menus:SelectEntry(menu, entry)
    local menuName = menu.triggerName:match("QuiverBtn_(.+)")
    -- For the aspects menu: slide the current selection into the "other" swap slot
    -- when the player picks a different aspect, giving right-click a toggle target.
    if menu.triggerName == "QuiverBtn_aspects"
            and menu.selected
            and menu.selected.spell ~= entry.spell then
        menu.otherSelected = menu.selected
        if menuName then
            Quiver.db.char.menuSelections[menuName .. "_other"] = menu.selected.spell
        end
    end
    menu.selected = entry
    if menuName then
        Quiver.db.char.menuSelections[menuName] = entry.spell
    end
    if menuName == "stings" and entry.spell then
        self:UpdateStingMacro(entry.spell)
    end

    -- SetNormalTexture is not combat-restricted; update icon immediately for visual feedback.
    -- Attribute (macrotext2) is deferred via selectionTicker → ApplySelectionToTrigger.
    -- Skip aspects: DetectCurrentAspect owns the aspects icon and tracks live state.
    if menu.triggerName ~= "QuiverBtn_aspects" then
        local triggerBtn = _G[menu.triggerName]
        if triggerBtn then
            local spellId = entry.spell and GetSpellId(entry.spell)
            local castTarget = spellId or entry.spell
            local icon = entry.icon
            if not icon and castTarget then
                local _, _, si = GetSpellInfo(castTarget)
                icon = si
            end
            if icon then
                triggerBtn:SetNormalTexture(icon)
                triggerBtn:SetPushedTexture(icon)
            end
        end
    end

    UpdateTriggerReadiness(menu)
    pendingSelectionMenu = menu
    selectionTicker:Show()
    self:HideAll()
end

function Menus:RebuildAll()
    if InCombatLockdown() then return end
    RefreshSpellCache()
    for _, menu in pairs(self.menus) do
        PopulateMenu(menu)
    end
    self:RebuildFoodPicker()
    self:UpdateTankOrbitButton()
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Menus:Toggle(menuName)
    if activeMenu == menuName then
        self:HideAll()
        activeMenu = nil
        return
    end
    self:HideAll()
    local menu = self.menus[menuName]
    if not menu or #menu.buttons == 0 then return end

    local inCombat = InCombatLockdown()
    for _, b in ipairs(menu.buttons) do
        if not inCombat then b:SetFrameStrata("DIALOG") end
        b:SetAlpha(1)
        if b.blocker then b.blocker:Hide() end
    end
    activeMenu = menuName
    if menuName == "traps" then
        cdTickerElapsed = 0
        cdTicker:Show()
        self:UpdateTrapCooldowns()
    end
end

function Menus:HideAll()
    local inCombat = InCombatLockdown()
    for _, menu in pairs(self.menus) do
        for _, b in ipairs(menu.buttons) do
            if not inCombat then b:SetFrameStrata("MEDIUM") end
            b:SetAlpha(0)
            if b.blocker then
                b.blocker:SetFrameStrata("MEDIUM")
                b.blocker:Show()
            end
        end
    end
    self:HideFoodPicker()
    cdTicker:Hide()
    activeMenu = nil
    -- Re-evaluate ticker now that activeMenu is nil: if any trap is still on
    -- cooldown this call will restart cdTicker so the trigger countdown stays live.
    self:UpdateTrapCooldowns()
end

function Menus:UpdateTrapCooldowns()
    local trapMenu = self.menus and self.menus.traps
    if not trapMenu then return end

    -- Use pre-computed cooldown data from the Traps module — avoids redundant
    -- GetSpellCooldown calls since Traps:UpdateCooldowns already read them and
    -- this function is called from that same code path (SPELL_UPDATE_COOLDOWN).
    local trapsData = Quiver.Modules.Traps.cooldowns
    local now = GetTime()
    local menuOpen = (activeMenu == "traps")

    local maxRemaining = 0
    for _, b in ipairs(trapMenu.buttons) do
        if b.cdSpell then
            local cd        = trapsData and trapsData[b.cdSpell]
            local start     = (cd and cd.start)    or 0
            local duration  = (cd and cd.duration) or 0
            local remaining = (duration > 1.5) and math.max(0, start + duration - now) or 0

            if remaining > maxRemaining then
                maxRemaining = remaining
            end

            -- Only update per-button visuals when the menu is actually open;
            -- when closed the buttons are invisible and the work is wasted.
            if menuOpen then
                if remaining > 0 then
                    if b.cdFrame then b.cdFrame:SetCooldown(start, duration) end
                    if b.cdDim  then b.cdDim:Show() end
                    if b.cdText then
                        -- Show tenths only for the last second; integer otherwise.
                        b.cdText:SetText(remaining >= 1 and math.ceil(remaining) or TENTHS_STR[math.floor(remaining * 10)] or "0.0")
                        b.cdText:Show()
                    end
                    if b._normalTex then b._normalTex:SetDesaturated(true) end
                else
                    if b.cdFrame then b.cdFrame:SetCooldown(0, 0) end
                    if b.cdDim  then b.cdDim:Hide() end
                    if b.cdText then b.cdText:Hide() end
                    if b._normalTex then b._normalTex:SetDesaturated(false) end
                end
            end
        end
    end

    -- Mirror the aggregate cooldown onto the trigger button (always updated)
    local triggerBtn = Menus._trapsTriggerBtn
    if triggerBtn and triggerBtn.cdDim and triggerBtn.cdText then
        -- Cache once; GetNormalTexture() may allocate a new userdata each call
        -- on some WoW client builds, so we avoid calling it every tick.
        if not triggerBtn._normalTex then
            triggerBtn._normalTex = triggerBtn:GetNormalTexture()
        end
        local triggerTex = triggerBtn._normalTex
        if maxRemaining > 0 then
            triggerBtn.cdDim:Show()
            triggerBtn.cdText:SetText(maxRemaining >= 1 and math.ceil(maxRemaining) or TENTHS_STR[math.floor(maxRemaining * 10)] or "0.0")
            triggerBtn.cdText:Show()
            if triggerTex then triggerTex:SetDesaturated(true) end
        else
            triggerBtn.cdDim:Hide()
            triggerBtn.cdText:Hide()
            if triggerTex then triggerTex:SetDesaturated(false) end
        end
    end

    -- Ticker lifecycle: keep cdTicker running whenever a trap is on cooldown so
    -- the trigger button countdown stays live even with the menu closed.
    -- Stop it only when no traps are cooling down and the menu is also closed.
    if maxRemaining > 0 then
        if not cdTicker:IsShown() then
            cdTickerElapsed = 0
            cdTicker:Show()
        end
    elseif not menuOpen then
        cdTicker:Hide()
    end
end

function Menus:HideFoodPicker()
    local inCombat = InCombatLockdown()
    for _, b in ipairs(foodPickerButtons) do
        if not inCombat then b:SetButtonState("NORMAL") end
        b:SetAlpha(0)
        if not inCombat then b:EnableMouse(false) end
    end
    foodPickerOpen = false
end

local function SetFoodOrbitIcon(btn, icon)
    -- NormalTexture/PushedTexture don't visually render numeric fileIDs on
    -- SecureActionButtonTemplate children in TBC Classic Anniversary.
    -- Use a dedicated OVERLAY texture (same approach as ContainerFrameItemButton).
    -- The PushedTexture (string path set at creation) renders ABOVE OVERLAY when
    -- the button is pressed, covering the icon. Overwrite it with the numeric ID
    -- so it becomes transparent during press, letting the OVERLAY show through.
    if not btn._foodIconTex then
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(btn)
        btn._foodIconTex = t
    end
    local pt = btn:GetPushedTexture()
    if icon then
        btn._foodIconTex:SetTexture(icon)
        btn._foodIconTex:Show()
        if pt then pt:SetTexture(icon) end
    else
        btn._foodIconTex:Hide()
        if pt then pt:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress") end
    end
end

function Menus:SelectFood(food)
    if InCombatLockdown() then return end
    Quiver.db.char.menuSelections.food = {
        name      = food.name,
        itemID    = food.itemID,
        isPetBuff = food.isPetBuff == true,
    }
    local btn = Menus._foodOrbitBtn
    if btn then
        local icon = food.icon
        if not icon or icon == 0 then
            for bag = 0, 4 do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    if C_Container.GetContainerItemID(bag, slot) == food.itemID then
                        local si = C_Container.GetContainerItemInfo(bag, slot)
                        if si and (si.iconFileID or 0) ~= 0 then
                            icon = si.iconFileID; break
                        end
                    end
                end
                if icon and icon ~= 0 then break end
            end
        end
        if not icon or icon == 0 then icon = select(10, GetItemInfo(food.itemID)) end
        SetFoodOrbitIcon(btn, icon)
        btn:SetAlpha(1.0)
        local macro = food.isPetBuff
            and ("/use " .. food.name)
            or  ("/cast Feed Pet\n/use " .. food.name)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", macro)
        if btn.countText then
            btn.countText:SetText(food.count > 1 and tostring(food.count) or "")
        end
        local verb = food.isPetBuff == true and "Right-click: use " or "Right-click: feed "
        local actionLine = verb .. food.name
        btn:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Feed Pet")
            GameTooltip:AddLine(actionLine, 0.4, 1, 0.4)
            GameTooltip:AddLine("Left-click: open food picker", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end
    self:HideFoodPicker()
end

function Menus:RefreshFoodOrbitCount()
    local btn = Menus._foodOrbitBtn
    if not btn or not btn.countText then return end
    local totalCount = 0
    local fs = Quiver.db and Quiver.db.char.menuSelections.food
    local savedID = fs and fs.itemID
    if savedID then
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if C_Container.GetContainerItemID(bag, slot) == savedID then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info then
                        totalCount = totalCount + (info.stackCount or 1)
                    end
                end
            end
        end
    end
    btn.countText:SetText(totalCount > 1 and tostring(totalCount) or "")
end

function Menus:RefreshFoodPicker(foods)
    foods = foods or Quiver.Modules.Pet:GetSuitableFood()
    for i, b in ipairs(foodPickerButtons) do
        local food = foods[i]
        if food then
            local icon = food.icon
            if not icon or icon == 0 then
                icon = select(10, GetItemInfo(food.itemID))
            end
            b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
            b:SetPushedTexture(icon or "Interface\\Buttons\\UI-Quickslot-Depress")
            b.countText:SetText(food.count > 1 and tostring(food.count) or "")
            b.itemID = food.itemID
            b.itemName = food.name
            if not InCombatLockdown() then
                -- left-click: select for quick-cast (no secure action, handled by PostClick)
                b:SetAttribute("type", nil)
                b:SetAttribute("macrotext", nil)
                -- right-click: feed/use immediately
                local macro = food.isPetBuff == true
                    and ("/use " .. food.name)
                    or  ("/cast Feed Pet\n/use " .. food.name)
                b:SetAttribute("type2", "macro")
                b:SetAttribute("macrotext2", macro)
                local capturedFood = food
                b:SetScript("PostClick", function(_, button)
                    if button == "LeftButton" then
                        Menus:SelectFood(capturedFood)
                    end
                    -- right-click: secure macro feeds pet; picker stays open so counts update live
                end)
            end
        else
            b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
            b.countText:SetText("")
            b.itemID = nil
            b.itemName = nil
            if not InCombatLockdown() then
                b:SetAttribute("type", nil)
                b:SetAttribute("macrotext", nil)
                b:SetAttribute("type2", nil)
                b:SetAttribute("macrotext2", nil)
                b:SetScript("PostClick", nil)
            end
        end
    end

    self:RefreshFoodOrbitCount()
end

function Menus:UpdateFoodOrbitButton()
    local btn = Menus._foodOrbitBtn
    if not btn or InCombatLockdown() then return end
    if not Quiver.Modules.Pet.exists then
        local _, _, feedIcon = GetSpellInfo("Feed Pet")
        SetFoodOrbitIcon(btn, feedIcon or nil)
        btn:SetAlpha(0.4)
        btn:SetAttribute("macrotext2", "")
        if btn.countText then btn.countText:SetText("") end
        btn:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Feed Pet")
            GameTooltip:AddLine("No pet active", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
    end
end

function Menus:RebuildFoodPicker()
    if InCombatLockdown() then return end
    if #foodPickerButtons == 0 then return end
    if not Quiver.Modules.Pet.exists then
        self:UpdateFoodOrbitButton()
        return
    end
    local anchor = Menus._foodOrbitBtn
    if not anchor then return end
    for i, b in ipairs(foodPickerButtons) do
        b:ClearAllPoints()
        b:SetPoint("LEFT", anchor, "RIGHT", 6 + (i - 1) * BUTTON_SPACING, 0)
    end
    local foods = Quiver.Modules.Pet:GetSuitableFood()
    self:RefreshFoodPicker(foods)

    -- Restore orbit button state from saved selection — update icon/macro/tooltip
    -- directly; never call SelectFood here (that closes the picker as a side effect).
    local fs = Quiver.db and Quiver.db.char.menuSelections.food
    local savedName = fs and fs.name
    local btn = Menus._foodOrbitBtn
    if not btn or InCombatLockdown() then return end

    if savedName then
        local foundFood = nil
        for _, food in ipairs(foods) do
            if food.name == savedName then foundFood = food; break end
        end

        local icon, isPetBuff
        if foundFood then
            icon      = foundFood.icon
            isPetBuff = foundFood.isPetBuff == true
        else
            local savedID = fs and fs.itemID
            if savedID then icon = select(10, GetItemInfo(savedID)) end
            if not icon or icon == 0 then icon = select(10, GetItemInfo(savedName)) end
            isPetBuff = fs and fs.isPetBuff == true
        end
        if not icon or icon == 0 then icon = nil end

        SetFoodOrbitIcon(btn, icon)
        btn:SetAlpha(1.0)
        local macro = isPetBuff
            and ("/use " .. savedName)
            or  ("/cast Feed Pet\n/use " .. savedName)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", macro)
        local verb = isPetBuff and "Right-click: use " or "Right-click: feed "
        local actionLine = verb .. savedName
        btn:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Feed Pet")
            GameTooltip:AddLine(actionLine, 0.4, 1, 0.4)
            GameTooltip:AddLine("Left-click: open food picker", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    else
        local _, _, feedIcon = GetSpellInfo("Feed Pet")
        SetFoodOrbitIcon(btn, feedIcon or nil)
        btn:SetAlpha(0.6)
        btn:SetAttribute("macrotext2", "")
        btn:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Feed Pet")
            GameTooltip:AddLine("Right-click: no food selected", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Left-click: open food picker", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
    end
end

function Menus:ToggleFoodPicker()
    if not Quiver.Modules.Pet.exists then return end
    if foodPickerOpen then
        self:HideFoodPicker()
    else
        local foods = Quiver.Modules.Pet:GetSuitableFood()
        self:RefreshFoodPicker(foods)
        local inCombat = InCombatLockdown()
        for i, b in ipairs(foodPickerButtons) do
            local hasFood = foods[i] ~= nil
            b:SetAlpha(hasFood and 1 or 0)
            if not inCombat then b:EnableMouse(hasFood) end
        end
        foodPickerOpen = true
    end
end

-- ── Managed macros ────────────────────────────────────────────────────────────

local function WriteMacro(name, iconSpell, body)
    local _, _, icon = GetSpellInfo(iconSpell or "")
    icon = icon or "INV_Misc_QuestionMark"
    local idx = GetMacroIndexByName(name)
    if idx > 0 then
        EditMacro(idx, name, icon, body)
    elseif GetNumMacros() < 36 then
        CreateMacro(name, icon, body, false)
    else
        print("|cffff4444Quiver:|r Macro book full (36/36). Free a slot and try again.")
    end
end

function Menus:UpdateStingMacro(spellName)
    if not spellName then return end
    WriteMacro("Quiver: Sting", spellName, "#showtooltip " .. spellName .. "\n/cast " .. spellName)
end

function Menus:BuildBWMacroBody()
    local lines = { "#showtooltip Bestial Wrath", "/cast Bestial Wrath" }
    if Quiver.db.profile.petTankMode then
        -- Only attempt Intimidation when a hostile target exists; avoids a
        -- visible "Invalid target" error when pressing BW with nothing targeted.
        lines[#lines+1] = "/cast [exists,harm,nodead,known:Intimidation] Intimidation"
    end
    return table.concat(lines, "\n")
end

function Menus:UpdateBWMacro()
    if InCombatLockdown() then
        -- EditMacro is blocked in combat; defer until PLAYER_REGEN_ENABLED.
        bwMacroPending = true
        return
    end
    bwMacroPending = false
    if GetMacroIndexByName("Quiver: BW") > 0 then
        WriteMacro("Quiver: BW", "Bestial Wrath", self:BuildBWMacroBody())
    end
end

-- Growl is a pet-only spell not in the player spellbook; GetSpellInfo returns
-- nil for it. Use the known taunt icon as a fallback when no pet is present.
local GROWL_FALLBACK_ICON = "Interface\\Icons\\Ability_Physical_Taunt"

local function FindGrowlInfo()
    for i = 1, 10 do
        local name, tex, isToken, _, _, autoCastEnabled = GetPetActionInfo(i)
        if name == "Growl" then
            return i, (not isToken) and tex or nil, autoCastEnabled == true
        end
    end
end

-- Called on login / zone change (RebuildAll). Reads Growl as the source of
-- truth to establish the initial petTankMode state, then wires the button.
function Menus:UpdateTankOrbitButton()
    local btn = Menus._tankOrbitBtn
    if not btn or InCombatLockdown() then return end
    local growlSlot, growlIcon, growlOn = FindGrowlInfo()
    if growlSlot and Quiver.db then
        Quiver.db.profile.petTankMode = growlOn
    end
    local icon = growlIcon or GROWL_FALLBACK_ICON
    btn:SetNormalTexture(icon)
    btn:SetPushedTexture(icon)
    if growlSlot then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/click PetActionButton" .. growlSlot .. " RightButton")
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    local tex = btn:GetNormalTexture()
    if tex then tex:SetDesaturated(not Quiver.db.profile.petTankMode) end
    self:UpdateBWMacro()
end

-- Called on PET_BAR_UPDATE (mount / dismount). Pushes the stored petTankMode
-- preference OUT to the button display and BW macro — does NOT read Growl back
-- into petTankMode, so a mount/dismount cycle cannot overwrite the user's choice.
function Menus:RefreshTankOrbitButton()
    local btn = Menus._tankOrbitBtn
    if not btn or InCombatLockdown() then return end
    local growlSlot, growlIcon = FindGrowlInfo()
    local icon = growlIcon or GROWL_FALLBACK_ICON
    btn:SetNormalTexture(icon)
    btn:SetPushedTexture(icon)
    if growlSlot then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/click PetActionButton" .. growlSlot .. " RightButton")
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    local enabled = Quiver.db and Quiver.db.profile.petTankMode
    local tex = btn:GetNormalTexture()
    if tex then tex:SetDesaturated(not enabled) end
    self:UpdateBWMacro()
end

function Menus:WriteManagedMacro(name, iconSpell, body)
    WriteMacro(name, iconSpell, body)
end

-- ── Menu definitions ──────────────────────────────────────────────────────────

local function NewMenu(btnName, displayName, growLeft, entries)
    local pool = {}
    for i = 1, #entries do pool[i] = CreateBlankButton() end
    return {
        triggerName   = btnName,
        displayName   = displayName,
        growLeft      = growLeft,
        entries       = entries,
        buttons       = {},
        pool          = pool,
        _lastSelected = UNSET_SELECTION,
    }
end

function Menus:Initialize()
    self.menus = {
        aspects = NewMenu("QuiverBtn_aspects", "Aspects", false, (function()
            local t = {}
            for _, a in ipairs(Quiver.Modules.Aspects.ASPECTS) do
                local name = a.name
                t[#t+1] = { spell = name, label = name:match("of the (.+)") or name }
            end
            return t
        end)()),

        pet = NewMenu("QuiverBtn_pet", "Pet", false, {
            { spell = "Call Pet",       label = "Call"    },
            { spell = "Dismiss Pet",    label = "Dismiss" },
            { spell = "Revive Pet",     label = "Revive"  },
            { spell = "Mend Pet",       label = "Mend"    },
            { spell = "Beast Training", label = "Train"   },
            { spell = "Beast Lore",     label = "Lore"    },
        }),

        stings = NewMenu("QuiverBtn_stings", "Stings", false, {
            { spell = "Serpent Sting", label = "Serpent" },
            { spell = "Viper Sting",   label = "Viper"   },
            { spell = "Scorpid Sting", label = "Scorpid" },
            { spell = "Wyvern Sting",  label = "Wyvern"  },
        }),

        traps = NewMenu("QuiverBtn_traps", "Traps", true, (function()
            local t = {}
            for _, trap in ipairs(Quiver.Modules.Traps.TRAPS) do
                t[#t+1] = { spell = trap.name, label = trap.name:match("^(%S+)"), icon = trap.icon, showCooldown = true }
            end
            return t
        end)()),

        tracking = NewMenu("QuiverBtn_tracking", "Tracking", true, (function()
            local t = {}
            for _, name in ipairs(Quiver.Modules.Tracking.TRACKING_SPELLS) do
                t[#t+1] = { spell = name, label = name:match("^%S+%s+(%S+)") or name }
            end
            return t
        end)()),
    }

    for i = 1, 5 do foodPickerButtons[i] = MakeFoodButton() end

    self:RebuildAll()

    local rebuildPending = false
    Quiver:RegisterEvent("SPELLS_CHANGED", function()
        if InCombatLockdown() then
            rebuildPending = true
        else
            Menus:RebuildAll()
            -- Sphere right-click macro depends on GetSpellInfo("Call Pet") which may
            -- have returned nil if UpdateOnClick ran before SPELLS_CHANGED populated
            -- the spell book. Rebuild it now that spells are guaranteed available.
            Quiver.UI.Sphere:UpdateOnClick()
        end
    end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Menus:RebuildAll()
        local stingSel = Quiver.db.char.menuSelections.stings
        if stingSel then Menus:UpdateStingMacro(stingSel) end
    end)
    Quiver:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if rebuildPending then
            rebuildPending = false
            Menus:RebuildAll()  -- RebuildAll → UpdateTankOrbitButton → UpdateBWMacro clears bwMacroPending
            Quiver.UI.Sphere:UpdateOnClick()
        else
            -- Refresh all menus: aspects swap macro tracks live aspect state, and any
            -- menu selection made in combat needs its icon + attribute written now.
            for _, menu in pairs(Menus.menus) do
                Menus:ApplySelectionToTrigger(menu)
            end
            if bwMacroPending then Menus:UpdateBWMacro() end
        end
    end)
    Quiver:RegisterEvent("BAG_UPDATE", function()
        if not foodPickerOpen then
            Menus:RefreshFoodOrbitCount()
        end
    end)
    Quiver:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if foodPickerOpen then
            Menus:RefreshFoodPicker()
        end
    end)

    -- Cache trigger button frame references; used in hot paths to avoid _G lookups.
    Menus._trapsTriggerBtn = _G["QuiverBtn_traps"]
    Menus._foodOrbitBtn    = _G["QuiverBtn_food"]
    Menus._tankOrbitBtn    = _G["QuiverBtn_tank"]

    -- PET_BAR_UPDATE fires when the pet action bar changes state — including when
    -- mounting hides the bar and dismounting restores it. Use a raw frame to avoid
    -- AceEvent handler collision with other modules registering the same event.
    local petBarFrame = CreateFrame("Frame")
    petBarFrame:RegisterEvent("PET_BAR_UPDATE")
    petBarFrame:SetScript("OnEvent", function()
        Menus:RefreshTankOrbitButton()
    end)
end
