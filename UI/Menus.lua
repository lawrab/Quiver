-- Expandable menus that appear around the sphere when a section button is clicked.
-- Menus filter to known spells only and rebuild on SPELLS_CHANGED.

local Menus = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Menus = Menus

local BUTTON_SIZE = 28
local BUTTON_SPACING = 34
local activeMenu = nil
local trash  -- hidden frame; recycled buttons are re-parented here

local function IsSpellKnown(spellName)
    return GetSpellInfo(spellName) ~= nil
end

-- ── Frame / button helpers ────────────────────────────────────────────────────

local function MakeMenuFrame(btnName, growLeft)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetHeight(BUTTON_SIZE + 20)
    f:SetWidth(1)
    f:Hide()
    f.growLeft = growLeft
    if growLeft then
        f:SetPoint("RIGHT", btnName, "LEFT", -6, 0)
    else
        f:SetPoint("LEFT", btnName, "RIGHT", 6, 0)
    end
    return f
end

local function MakeActionButton(parent, label, icon, onClick, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(BUTTON_SIZE)
    b:SetHeight(BUTTON_SIZE)
    if parent.growLeft then
        b:SetPoint("RIGHT", parent, "RIGHT", -(index - 1) * BUTTON_SPACING, 0)
    else
        b:SetPoint("LEFT", parent, "LEFT", (index - 1) * BUTTON_SPACING, 0)
    end
    b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(b)
    b.cooldown = cd
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOM", b, "BOTTOM", 0, -2)
    text:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- ── Menu rebuild ──────────────────────────────────────────────────────────────

local function RecycleMenu(menu)
    if menu.buttons then
        for _, b in ipairs(menu.buttons) do
            b:SetParent(trash)
            b:ClearAllPoints()
            b:Hide()
        end
    end
    menu.buttons = {}
    menu.frame:SetWidth(1)
end

local function PopulateMenu(menu)
    RecycleMenu(menu)
    local idx = 0
    for _, entry in ipairs(menu.entries) do
        if not entry.spell or IsSpellKnown(entry.spell) then
            idx = idx + 1
            local icon = entry.icon
            if not icon and entry.spell then
                local _, _, spellIcon = GetSpellInfo(entry.spell)
                icon = spellIcon
            end
            local b = MakeActionButton(menu.frame, entry.label, icon, entry.onClick, idx)
            table.insert(menu.buttons, b)
        end
    end
    menu.frame:SetWidth(math.max(1, idx * BUTTON_SPACING))

    -- Show lock icon when menu has no known spells; restore spell icon when it does
    local triggerBtn = _G[menu.frame.triggerName]
    if triggerBtn then
        if idx == 0 then
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
            -- Restore the original spell icon
            local _, _, icon = GetSpellInfo(triggerBtn.spellHint or "")
            if icon then
                triggerBtn:SetNormalTexture(icon)
                triggerBtn:SetPushedTexture(icon)
            end
            local menuName = menu.frame.triggerName:match("QuiverBtn_(.+)")
            triggerBtn:SetScript("OnClick", function()
                Quiver.UI.Menus:Toggle(menuName)
            end)
            triggerBtn:SetScript("OnEnter", nil)
            triggerBtn:SetScript("OnLeave", nil)
        end
    end
end

function Menus:RebuildAll()
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
    if menu then
        menu.frame:Show()
        activeMenu = menuName
    end
end

function Menus:HideAll()
    for _, menu in pairs(self.menus) do
        menu.frame:Hide()
    end
    activeMenu = nil
end

function Menus:UpdateTrapCooldowns()
end

-- ── Menu definitions ──────────────────────────────────────────────────────────

local function NewMenu(btnName, growLeft, entries)
    local f = MakeMenuFrame(btnName, growLeft)
    f.triggerName = btnName
    return {
        frame    = f,
        growLeft = growLeft,
        entries  = entries,
        buttons  = {},
    }
end

function Menus:Initialize()
    trash = trash or CreateFrame("Frame", nil, UIParent)
    trash:Hide()

    local function hideAll() Menus:HideAll() end

    self.menus = {
        -- A at top (angle 90) — expand right
        aspects = NewMenu("QuiverBtn_aspects", false, (function()
            local t = {}
            for _, a in ipairs(Quiver.Modules.Aspects.ASPECTS) do
                local name = a.name
                t[#t+1] = {
                    spell   = name,
                    label   = name:match("of the (.+)") or name,
                    onClick = function() Quiver.Modules.Aspects:Cast(name) hideAll() end,
                }
            end
            return t
        end)()),

        -- P at upper-right (angle 30) — expand right
        pet = NewMenu("QuiverBtn_pet", false, {
            { spell = "Call Pet",    label = "Call",    onClick = function() Quiver.Modules.Pet:CallPet()    hideAll() end },
            { spell = "Dismiss Pet", label = "Dismiss", onClick = function() Quiver.Modules.Pet:DismissPet() hideAll() end },
            { spell = "Revive Pet",  label = "Revive",  onClick = function() Quiver.Modules.Pet:RevivePet()  hideAll() end },
            { spell = "Mend Pet",    label = "Mend",    onClick = function() Quiver.Modules.Pet:MendPet()    hideAll() end },
        }),

        -- T at lower-left (angle 210) — expand left
        traps = NewMenu("QuiverBtn_traps", true, (function()
            local t = {}
            for _, trap in ipairs(Quiver.Modules.Traps.TRAPS) do
                local name = trap.name
                t[#t+1] = {
                    spell   = name,
                    label   = name:match("^(%S+)"),
                    icon    = trap.icon,
                    onClick = function() Quiver.Modules.Traps:Cast(name) hideAll() end,
                }
            end
            return t
        end)()),

        -- Tr at upper-left (angle 150) — expand left
        tracking = NewMenu("QuiverBtn_tracking", true, (function()
            local t = {}
            for _, spellName in ipairs(Quiver.Modules.Tracking.TRACKING_SPELLS) do
                local name = spellName
                t[#t+1] = {
                    spell   = name,
                    label   = name:match("^%S+%s+(%S+)") or name,
                    onClick = function() Quiver.Modules.Tracking:Cast(name) hideAll() end,
                }
            end
            return t
        end)()),
    }

    self:RebuildAll()

    Quiver:RegisterEvent("SPELLS_CHANGED", function() Menus:RebuildAll() end)
end
