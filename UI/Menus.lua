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
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", macroText)
        end
    end
    -- Match ActionButtonUseKeyDown CVar so click fires at the right time
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")
    b:Hide()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(label)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- ── Menu rebuild ──────────────────────────────────────────────────────────────

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
            table.insert(menu.buttons, b)
        end
    end

    -- Update trigger button state
    local triggerBtn = _G[menu.triggerName]
    if not triggerBtn then return end

    if #menu.buttons == 0 then
        triggerBtn:SetAlpha(0.7)
        triggerBtn:SetNormalTexture("Interface\\AddOns\\Quiver\\Media\\lock")
        triggerBtn:SetPushedTexture("Interface\\AddOns\\Quiver\\Media\\lock")
        triggerBtn:SetScript("OnClick", nil)
        triggerBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(triggerBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("No spells learned yet", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        triggerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        triggerBtn:SetAlpha(1.0)
        local hintId = GetSpellId(triggerBtn.spellHint or "")
        local hintTarget = hintId or triggerBtn.spellHint or ""
        local _, _, icon = GetSpellInfo(hintTarget)
        if icon then
            triggerBtn:SetNormalTexture(icon)
            triggerBtn:SetPushedTexture(icon)
        end
        local menuName = menu.triggerName:match("QuiverBtn_(.+)")
        triggerBtn:SetScript("OnClick", function()
            Quiver.UI.Menus:Toggle(menuName)
        end)
        triggerBtn:SetScript("OnEnter", nil)
        triggerBtn:SetScript("OnLeave", nil)
    end
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
    end
    activeMenu = menuName
end

function Menus:HideAll()
    for _, menu in pairs(self.menus) do
        for _, b in ipairs(menu.buttons) do
            b:Hide()
        end
    end
    activeMenu = nil
end

function Menus:UpdateTrapCooldowns()
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
                t[#t+1] = { spell = trap.name, label = trap.name:match("^(%S+)"), icon = trap.icon }
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
end
