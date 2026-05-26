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

-- Deferred attribute application: SetAttribute on secure frames from PostClick
-- (after a secure action fired) can be silently blocked in TBC Classic.
-- We write the pending menu here and apply it on the very next OnUpdate frame.
local pendingSelectionMenu = nil
local selectionTicker = CreateFrame("Frame")
selectionTicker:SetScript("OnUpdate", function()
    if pendingSelectionMenu and not InCombatLockdown() then
        local m = pendingSelectionMenu
        pendingSelectionMenu = nil
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
            if spellType == "SPELL" then
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

local function MakeActionButton(label, icon, spellCast)
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b:SetWidth(BUTTON_SIZE)
    b:SetHeight(BUTTON_SIZE)
    b:SetFrameStrata("DIALOG")
    b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    if spellCast then
        local macroText
        if type(spellCast) == "number" then
            local name = GetSpellInfo(spellCast)
            macroText = name and ("/cast " .. name) or nil
        else
            macroText = "/cast " .. spellCast
        end
        if macroText then
            b:SetAttribute("type2", "macro")
            b:SetAttribute("macrotext2", macroText)
        end
    end
    -- Match ActionButtonUseKeyDown CVar so click fires at the right time
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")
    b:Hide()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(label)
        GameTooltip:AddLine("Left-click: select for quick-cast", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Right-click: cast now", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- ── Menu rebuild ──────────────────────────────────────────────────────────────

local function UpdateTriggerReadiness(menu)
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end
    local section = menu.triggerName:match("QuiverBtn_(.+)") or ""
    section = section:sub(1,1):upper() .. section:sub(2)
    if menu.selected then
        triggerBtn:SetAlpha(1.0)
        local spellName = menu.selected.spell or ""
        triggerBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(section)
            GameTooltip:AddLine("Left-click: open menu", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Right-click: " .. spellName, 0.4, 1, 0.4)
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
    -- Hide and release old buttons (can't destroy frames in WoW)
    for _, b in ipairs(menu.buttons) do
        b:Hide()
        b:ClearAllPoints()
    end
    menu.buttons = {}

    for _, entry in ipairs(menu.entries) do
        if not entry.spell or IsSpellKnown(entry.spell) then
            local icon = entry.icon
            local spellId = entry.spell and GetSpellId(entry.spell)
            -- cast target: numeric ID when available, spell name as fallback
            local castTarget = spellId or entry.spell
            if not icon and castTarget then
                local _, _, spellIcon = GetSpellInfo(castTarget)
                icon = spellIcon
            end
            local b = MakeActionButton(entry.label, icon, castTarget)
            if entry.showCooldown and entry.spell then
                local cd = CreateFrame("Cooldown", nil, b)
                cd:SetAllPoints(b)
                cd.noOCC = true
                cd.noCooldownCount = true
                b.cdFrame = cd
                b.cdSpell = entry.spell
                -- Dark tint over the icon — definitely visible even if Cooldown
                -- frame sweep doesn't render in this WoW build.
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
            local capturedEntry = entry
            b:SetScript("PostClick", function(_, button)
                if button == "LeftButton" then
                    Menus:SelectEntry(menu, capturedEntry)
                end
            end)
            table.insert(menu.buttons, b)
        end
    end

    -- Pre-position buttons at their open layout and show them invisible.
    -- SetPoint is only legal outside combat; PopulateMenu is always called
    -- outside combat (guarded by RebuildAll). Toggle/HideAll then only need
    -- SetAlpha, which is not protected and works during combat lockdown.
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end

    for i, b in ipairs(menu.buttons) do
        b:ClearAllPoints()
        if menu.growLeft then
            b:SetPoint("RIGHT", triggerBtn, "LEFT", -6 - (i - 1) * BUTTON_SPACING, 0)
        else
            b:SetPoint("LEFT", triggerBtn, "RIGHT", 6 + (i - 1) * BUTTON_SPACING, 0)
        end
        b:Show()
        b:SetAlpha(0)
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
            triggerBtn:SetAttribute("type2", "macro")
            triggerBtn:SetAttribute("macrotext2", "/cast " .. name)
            return
        end
    end
    triggerBtn:SetAttribute("type2", nil)
    triggerBtn:SetAttribute("macrotext2", nil)
end

function Menus:SelectEntry(menu, entry)
    menu.selected = entry
    local menuName = menu.triggerName:match("QuiverBtn_(.+)")
    if menuName then
        Quiver.db.char.menuSelections[menuName] = entry.spell
    end

    -- Update trigger icon
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

    UpdateTriggerReadiness(menu)
    pendingSelectionMenu = menu
    self:HideAll()
end

function Menus:RebuildAll()
    if InCombatLockdown() then return end
    RefreshSpellCache()
    for _, menu in pairs(self.menus) do
        PopulateMenu(menu)
    end
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

    for _, b in ipairs(menu.buttons) do
        b:SetAlpha(1)
    end
    activeMenu = menuName
    if menuName == "traps" then
        self:UpdateTrapCooldowns()
    end
end

function Menus:HideAll()
    for _, menu in pairs(self.menus) do
        for _, b in ipairs(menu.buttons) do
            b:SetAlpha(0)
        end
    end
    activeMenu = nil
end

function Menus:UpdateTrapCooldowns()
    local trapMenu = self.menus and self.menus.traps
    if not trapMenu then return end

    local maxRemaining, maxStart, maxDuration = 0, 0, 0
    for _, b in ipairs(trapMenu.buttons) do
        if b.cdSpell then
            local start, duration = GetSpellCooldown(b.cdSpell)
            local remaining = (start and duration and duration > 1.5) and (start + duration - GetTime()) or 0
            if remaining > 0 then
                if b.cdFrame then b.cdFrame:SetCooldown(start, duration) end
                if b.cdDim  then b.cdDim:Show() end
                if b.cdText then
                    b.cdText:SetText(remaining >= 10 and math.floor(remaining) or string.format("%.1f", remaining))
                    b.cdText:Show()
                end
                local tex = b:GetNormalTexture()
                if tex then tex:SetDesaturated(true) end
                if remaining > maxRemaining then
                    maxRemaining, maxStart, maxDuration = remaining, start, duration
                end
            else
                if b.cdFrame then b.cdFrame:SetCooldown(0, 0) end
                if b.cdDim  then b.cdDim:Hide() end
                if b.cdText then b.cdText:Hide() end
                local tex = b:GetNormalTexture()
                if tex then tex:SetDesaturated(false) end
            end
        end
    end

    -- Mirror the cooldown onto the trigger button
    local triggerBtn = _G["QuiverBtn_traps"]
    if triggerBtn and triggerBtn.cdDim then
        local triggerTex = triggerBtn:GetNormalTexture()
        if maxRemaining > 0 then
            triggerBtn.cdDim:Show()
            triggerBtn.cdText:SetText(maxRemaining >= 10 and math.floor(maxRemaining) or string.format("%.1f", maxRemaining))
            triggerBtn.cdText:Show()
            if triggerTex then triggerTex:SetDesaturated(true) end
        else
            triggerBtn.cdDim:Hide()
            triggerBtn.cdText:Hide()
            if triggerTex then triggerTex:SetDesaturated(false) end
        end
    end
end

-- ── Menu definitions ──────────────────────────────────────────────────────────

local function NewMenu(btnName, growLeft, entries)
    return {
        triggerName = btnName,
        growLeft    = growLeft,
        entries     = entries,
        buttons     = {},
    }
end

function Menus:Initialize()
    self.menus = {
        aspects = NewMenu("QuiverBtn_aspects", false, (function()
            local t = {}
            for _, a in ipairs(Quiver.Modules.Aspects.ASPECTS) do
                local name = a.name
                t[#t+1] = { spell = name, label = name:match("of the (.+)") or name }
            end
            return t
        end)()),

        pet = NewMenu("QuiverBtn_pet", false, {
            { spell = "Call Pet",       label = "Call"    },
            { spell = "Dismiss Pet",    label = "Dismiss" },
            { spell = "Revive Pet",     label = "Revive"  },
            { spell = "Mend Pet",       label = "Mend"    },
            { spell = "Beast Training", label = "Train"   },
        }),

        traps = NewMenu("QuiverBtn_traps", true, (function()
            local t = {}
            for _, trap in ipairs(Quiver.Modules.Traps.TRAPS) do
                t[#t+1] = { spell = trap.name, label = trap.name:match("^(%S+)"), icon = trap.icon, showCooldown = true }
            end
            return t
        end)()),

        tracking = NewMenu("QuiverBtn_tracking", true, (function()
            local t = {}
            for _, name in ipairs(Quiver.Modules.Tracking.TRACKING_SPELLS) do
                t[#t+1] = { spell = name, label = name:match("^%S+%s+(%S+)") or name }
            end
            return t
        end)()),
    }

    self:RebuildAll()

    Quiver:RegisterEvent("SPELLS_CHANGED", function() Menus:RebuildAll() end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() Menus:RebuildAll() end)
    Quiver:RegisterEvent("PLAYER_REGEN_ENABLED", function() Menus:RebuildAll() end)

    -- Live countdown while the trap menu is open
    local cdTicker = CreateFrame("Frame")
    local elapsed = 0
    cdTicker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.1 then
            elapsed = 0
            Menus:UpdateTrapCooldowns()
        end
    end)
end
