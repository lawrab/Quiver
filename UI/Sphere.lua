-- Central sphere frame: draggable orb, color reflects active aspect,
-- shows ammo count and small status indicators around it.

local Sphere = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Sphere = Sphere

local SPHERE_SIZE = 80
local INDICATOR_SIZE = 12

function Sphere:Initialize()
    local f = CreateFrame("Button", "QuiverSphere", UIParent, "SecureActionButtonTemplate")
    f:SetWidth(SPHERE_SIZE)
    f:SetHeight(SPHERE_SIZE)
    f:SetPoint("CENTER", UIParent, "CENTER",
        Quiver.db.profile.sphere.x,
        Quiver.db.profile.sphere.y)
    f:SetFrameStrata("MEDIUM")
    f:SetScale(Quiver.db.profile.sphere.scale)
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    f:RegisterForClicks(keydown and "AnyDown" or "AnyUp")

    -- Sphere base texture
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture("Interface\\AddOns\\Quiver\\Media\\sphere")
    bg:SetVertexColor(0.55, 0.62, 0.85, 1)
    self.bg = bg

    -- Aspect color overlay (additive — tints the orb per active aspect)
    local overlay = f:CreateTexture(nil, "ARTWORK")
    overlay:SetAllPoints(f)
    overlay:SetTexture("Interface\\AddOns\\Quiver\\Media\\sphere")
    overlay:SetBlendMode("ADD")
    overlay:SetVertexColor(0, 0, 0, 0)
    self.overlay = overlay

    -- Ammo count text in center
    local ammoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ammoText:SetPoint("CENTER", f, "CENTER", 0, 0)
    self.ammoText = ammoText

    -- Pet happiness ring border around the sphere
    local petRing = f:CreateTexture(nil, "BACKGROUND")
    petRing:SetTexture("Interface\\AddOns\\Quiver\\Media\\ring")
    petRing:SetPoint("CENTER", f, "CENTER", 0, 0)
    petRing:SetWidth(SPHERE_SIZE)
    petRing:SetHeight(SPHERE_SIZE)
    petRing:SetVertexColor(0.3, 0.3, 0.3, 0)
    self.petRing = petRing

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

    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Quiver", 1, 0.82, 0)
        local lc = Quiver.db.profile.sphere.leftClick
        local rc = Quiver.db.profile.sphere.rightClick
        if lc ~= "none" then
            GameTooltip:AddLine("Left-click: " .. lc, 1, 1, 1)
        end
        if rc ~= "none" then
            GameTooltip:AddLine("Right-click: " .. rc, 1, 1, 1)
        end
        GameTooltip:AddLine("Alt+Right-click: Settings", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetScript("PostClick", function(self, button)
        if button == "RightButton" and IsAltKeyDown() then
            Quiver.UI.Config:Toggle()
        end
    end)

    self.frame = f
    self:SetupDrag(f)
    self:SetupMenuButtons(f)
    self:UpdateOnClick()

    f:Show()
end

function Sphere:SetupDrag(f)
    f:SetMovable(true)
    local moving = false
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() and not Quiver.db.profile.sphere.locked then
            self:StartMoving()
            moving = true
        end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and moving then
            self:StopMovingOrSizing()
            moving = false
            local _, _, _, x, y = self:GetPoint()
            Quiver.db.profile.sphere.x = x
            Quiver.db.profile.sphere.y = y
        end
    end)
end

function Sphere:SetupMenuButtons(f)
    -- Representative spell for each section — icon pulled from GetSpellInfo
    local buttons = {
        { name = "aspects",  angle = 90,  spell = "Aspect of the Hawk" },
        { name = "pet",      angle = 30,  spell = "Call Pet" },
        { name = "traps",    angle = 210, spell = "Frost Trap" },
        { name = "tracking", angle = 150, spell = "Track Beasts" },
    }

    local BTN_SIZE = 26
    local radius = SPHERE_SIZE / 2 + BTN_SIZE / 2 + 6
    for _, btn in ipairs(buttons) do
        local b = CreateFrame("Button", "QuiverBtn_"..btn.name, f)
        b:SetWidth(BTN_SIZE)
        b:SetHeight(BTN_SIZE)
        local rad = math.rad(btn.angle)
        b:SetPoint("CENTER", f, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius)

        -- Icon from spell, fallback to empty slot; store hint for later restore
        local _, _, icon = GetSpellInfo(btn.spell)
        b.spellHint = btn.spell
        b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
        b:SetPushedTexture(icon or "Interface\\Buttons\\UI-Quickslot-Depress")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

        local menuName = btn.name
        b:SetScript("OnClick", function()
            Quiver.UI.Menus:Toggle(menuName)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(btn.name:sub(1,1):upper()..btn.name:sub(2))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end

function Sphere:UpdateOnClick()
    local f = self.frame
    if not f or InCombatLockdown() then return end

    local lc = Quiver.db.profile.sphere.leftClick
    local rc = Quiver.db.profile.sphere.rightClick

    f:SetAttribute("type", nil)
    f:SetAttribute("macrotext", nil)
    f:SetAttribute("alt-type", nil)
    f:SetAttribute("alt-macrotext", nil)
    f:SetAttribute("type2", nil)
    f:SetAttribute("macrotext2", nil)
    f:SetAttribute("alt-type2", nil)
    f:SetAttribute("alt-macrotext2", nil)

    if lc ~= "none" then
        f:SetAttribute("type", "macro")
        f:SetAttribute("macrotext", "/cast " .. lc)
        -- Alt+LeftClick is reserved for drag; suppress the spell cast
        f:SetAttribute("alt-type", "macro")
        f:SetAttribute("alt-macrotext", "")
    end

    if rc ~= "none" then
        f:SetAttribute("type2", "macro")
        f:SetAttribute("macrotext2", "/cast " .. rc)
        -- Alt+RightClick reserved for config panel
        f:SetAttribute("alt-type2", "macro")
        f:SetAttribute("alt-macrotext2", "")
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
    if self.petRing then
        if Quiver.Modules.Pet.exists then
            local r, g, b = Quiver.Modules.Pet:GetHappinessColor()
            self.petRing:SetVertexColor(r, g, b, 0.85)
        else
            self.petRing:SetVertexColor(0, 0, 0, 0)
        end
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
