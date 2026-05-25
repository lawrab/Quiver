-- Central sphere frame: draggable orb, color reflects active aspect,
-- shows ammo count and small status indicators around it.

local Sphere = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Sphere = Sphere

local SPHERE_SIZE = 64
local INDICATOR_SIZE = 12

function Sphere:Initialize()
    local f = CreateFrame("Button", "QuiverSphere", UIParent)
    f:SetWidth(SPHERE_SIZE)
    f:SetHeight(SPHERE_SIZE)
    f:SetPoint("CENTER", UIParent, "CENTER",
        Quiver.db.profile.sphere.x,
        Quiver.db.profile.sphere.y)
    f:SetFrameStrata("MEDIUM")
    f:SetScale(Quiver.db.profile.sphere.scale)

    -- Dark orb background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0.1, 0.1, 0.15, 1)
    self.bg = bg

    -- Aspect color overlay (additive blend tints the orb)
    local overlay = f:CreateTexture(nil, "ARTWORK")
    overlay:SetAllPoints(f)
    overlay:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    overlay:SetBlendMode("ADD")
    overlay:SetVertexColor(0, 0, 0, 0)
    self.overlay = overlay

    -- Ammo count text in center
    local ammoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ammoText:SetPoint("CENTER", f, "CENTER", 0, 0)
    self.ammoText = ammoText

    -- Pet happiness dot (bottom-left)
    local petDot = f:CreateTexture(nil, "OVERLAY")
    petDot:SetWidth(INDICATOR_SIZE)
    petDot:SetHeight(INDICATOR_SIZE)
    petDot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
    petDot:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    petDot:SetVertexColor(0.5, 0.5, 0.5)
    self.petDot = petDot

    -- Sting duration bar (bottom of sphere)
    local stingBar = CreateFrame("StatusBar", nil, f)
    stingBar:SetWidth(SPHERE_SIZE - 8)
    stingBar:SetHeight(4)
    stingBar:SetPoint("BOTTOM", f, "BOTTOM", 0, -8)
    stingBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    stingBar:SetStatusBarColor(0.2, 0.8, 0.2)
    stingBar:SetMinMaxValues(0, 1)
    stingBar:SetValue(0)
    self.stingBar = stingBar

    self:SetupDrag(f)
    self:SetupMenuButtons(f)

    f:Show()
    self.frame = f
end

function Sphere:SetupDrag(f)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not Quiver.db.profile.sphere.locked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        Quiver.db.profile.sphere.x = x
        Quiver.db.profile.sphere.y = y
    end)
end

function Sphere:SetupMenuButtons(f)
    -- Menu trigger buttons arranged around the orb
    -- Each calls Quiver.UI.Menus:Toggle(menuName)
    local buttons = {
        { name = "aspects",  angle = 90,  label = "A" },
        { name = "pet",      angle = 30,  label = "P" },
        { name = "stings",   angle = 330, label = "S" },
        { name = "traps",    angle = 210, label = "T" },
        { name = "tracking", angle = 150, label = "Tr" },
    }

    local radius = SPHERE_SIZE / 2 + 12
    for _, btn in ipairs(buttons) do
        local b = CreateFrame("Button", "QuiverBtn_"..btn.name, f)
        b:SetWidth(20)
        b:SetHeight(20)
        local rad = math.rad(btn.angle)
        b:SetPoint("CENTER", f, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius)
        b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(b)
        label:SetText(btn.label)
        local menuName = btn.name
        b:SetScript("OnClick", function()
            Quiver.UI.Menus:Toggle(menuName)
        end)
    end
end

function Sphere:Show()
    if self.frame then self.frame:Show() end
end

function Sphere:Hide()
    if self.frame then self.frame:Hide() end
end

function Sphere:UpdateColor()
    local r, g, b = Quiver.Modules.Aspects:GetCurrentColor()
    if self.overlay then
        self.overlay:SetVertexColor(r, g, b, 0.6)
    end
end

function Sphere:UpdateAmmoDisplay()
    local count = Quiver.Modules.Ammo:GetCount()
    if self.ammoText then
        self.ammoText:SetText(count > 0 and tostring(count) or "")
        if count < Quiver.db.profile.ammoWarnThreshold then
            self.ammoText:SetTextColor(1, 0.2, 0.2)
        else
            self.ammoText:SetTextColor(1, 1, 1)
        end
    end
end

function Sphere:FlashAmmoWarning()
    -- TODO: brief red flash animation on the sphere frame
end

function Sphere:UpdatePetIndicator()
    if self.petDot then
        local r, g, b = Quiver.Modules.Pet:GetHappinessColor()
        self.petDot:SetVertexColor(r, g, b)
        self.petDot:SetShown(Quiver.Modules.Pet.exists)
    end
end

function Sphere:UpdateStingDisplay()
    if not self.stingBar then return end
    local sting = Quiver.Modules.Stings.active
    if sting then
        local remaining = Quiver.Modules.Stings:GetTimeRemaining()
        self.stingBar:SetMinMaxValues(0, sting.duration)
        self.stingBar:SetValue(remaining)
        self.stingBar:Show()
    else
        self.stingBar:Hide()
    end
end

function Sphere:UpdateTrackingIndicator()
    -- TODO: show small tracking icon on sphere edge
end
