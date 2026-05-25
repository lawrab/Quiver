-- Expandable menus that appear around the sphere when a section button is clicked

local Menus = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Menus = Menus

local BUTTON_SIZE = 28
local BUTTON_SPACING = 32
local activeMenu = nil

function Menus:Initialize()
    self.menus = {
        aspects  = self:BuildAspectsMenu(),
        pet      = self:BuildPetMenu(),
        stings   = self:BuildStingsMenu(),
        traps    = self:BuildTrapsMenu(),
        tracking = self:BuildTrackingMenu(),
    }
end

function Menus:Toggle(menuName)
    if activeMenu == menuName then
        self:HideAll()
        activeMenu = nil
        return
    end
    self:HideAll()
    if self.menus[menuName] then
        self.menus[menuName]:Show()
        activeMenu = menuName
    end
end

function Menus:HideAll()
    for _, menu in pairs(self.menus) do
        menu:Hide()
    end
end

function Menus:UpdateTrapCooldowns()
    -- Called by Traps module when cooldowns update
    -- Individual trap buttons on the trap menu will update their cooldown text
end

local function MakeMenuFrame(anchor, anchorPoint, xOff, yOff)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetPoint(anchorPoint, anchor, anchorPoint, xOff, yOff)
    f:SetFrameStrata("HIGH")
    f:Hide()
    return f
end

local function MakeActionButton(parent, label, icon, onClick, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(BUTTON_SIZE)
    b:SetHeight(BUTTON_SIZE)
    b:SetPoint("LEFT", parent, "LEFT", (index - 1) * BUTTON_SPACING, 0)
    if icon then
        b:SetNormalTexture(icon)
        b:SetPushedTexture(icon)
    end
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

function Menus:BuildAspectsMenu()
    local f = MakeMenuFrame(QuiverSphere, "BOTTOM", 0, -10)
    f:SetWidth(#Quiver.Modules.Aspects.ASPECTS * BUTTON_SPACING)
    f:SetHeight(BUTTON_SIZE + 20)
    for i, aspect in ipairs(Quiver.Modules.Aspects.ASPECTS) do
        local name = aspect.name
        MakeActionButton(f, aspect.name:match("of the (.+)"), nil, function()
            Quiver.Modules.Aspects:Cast(name)
            Menus:HideAll()
        end, i)
    end
    return f
end

function Menus:BuildPetMenu()
    local f = MakeMenuFrame(QuiverSphere, "TOPRIGHT", 10, 10)
    f:SetWidth(4 * BUTTON_SPACING)
    f:SetHeight(BUTTON_SIZE + 20)
    local actions = {
        { label = "Call",    fn = function() Quiver.Modules.Pet:CallPet()    end },
        { label = "Dismiss", fn = function() Quiver.Modules.Pet:DismissPet() end },
        { label = "Revive",  fn = function() Quiver.Modules.Pet:RevivePet()  end },
        { label = "Mend",    fn = function() Quiver.Modules.Pet:MendPet()    end },
    }
    for i, action in ipairs(actions) do
        local fn = action.fn
        MakeActionButton(f, action.label, nil, function()
            fn()
            Menus:HideAll()
        end, i)
    end
    return f
end

function Menus:BuildStingsMenu()
    local f = MakeMenuFrame(QuiverSphere, "BOTTOMRIGHT", 10, -10)
    f:SetWidth(#Quiver.Modules.Stings.STINGS * BUTTON_SPACING)
    f:SetHeight(BUTTON_SIZE + 20)
    for i, sting in ipairs(Quiver.Modules.Stings.STINGS) do
        local name = sting.name
        MakeActionButton(f, sting.name:match("^(%S+)"), nil, function()
            Quiver.Modules.Stings:Cast(name)
            Menus:HideAll()
        end, i)
    end
    return f
end

function Menus:BuildTrapsMenu()
    local f = MakeMenuFrame(QuiverSphere, "BOTTOMLEFT", -10, -10)
    f:SetWidth(#Quiver.Modules.Traps.TRAPS * BUTTON_SPACING)
    f:SetHeight(BUTTON_SIZE + 20)
    for i, trap in ipairs(Quiver.Modules.Traps.TRAPS) do
        local name = trap.name
        local b = MakeActionButton(f, trap.name:match("^(%S+)"), trap.icon, function()
            Quiver.Modules.Traps:Cast(name)
            Menus:HideAll()
        end, i)
        b.trapName = name
        b.cdLabel = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.cdLabel:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    return f
end

function Menus:BuildTrackingMenu()
    local f = MakeMenuFrame(QuiverSphere, "TOPLEFT", -10, 10)
    f:SetWidth(#Quiver.Modules.Tracking.TRACKING_SPELLS * BUTTON_SPACING)
    f:SetHeight(BUTTON_SIZE + 20)
    for i, spellName in ipairs(Quiver.Modules.Tracking.TRACKING_SPELLS) do
        local name = spellName
        MakeActionButton(f, spellName:match("^%S+%s*(%S*)") or spellName, nil, function()
            Quiver.Modules.Tracking:Cast(name)
            Menus:HideAll()
        end, i)
    end
    return f
end
