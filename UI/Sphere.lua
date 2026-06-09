-- Central sphere frame: draggable orb, color reflects active aspect,
-- shows ammo count and small status indicators around it.

local Sphere = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Sphere = Sphere

local SPHERE_SIZE = 80
local BAR_WIDTH   = 102  -- spans traps (210°) to food (330°) button centers horizontally
local _autoShotMod  -- cached after Initialize; avoids global chain lookup every frame

-- Pre-allocated color constants — reused every call, never re-created
local PULSE_COLOR_MANA_LOW  = {0.3,  0.5,  1.0 }
local PULSE_COLOR_NO_ASPECT = {0.75, 0.08, 0.12}
local BAR_COLOR_NORMAL      = {1.0,  0.7,  0.0 }  -- gold
local BAR_COLOR_HASTE       = {0.3,  0.9,  1.0 }  -- cyan: Rapid Fire / haste proc

local function BindingLabel(bType, spell, macro)
    if bType == "spell" and spell ~= "none" then return spell end
    if bType == "macro" and (macro or "") ~= "" then
        return (macro:match("([^\n]+)") or "[Macro]")
    end
end

local function HasBinding(bType, spell, macro)
    if bType == "spell" then return spell ~= "none" end
    if bType == "macro" then return (macro or "") ~= "" end
end

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
    -- BORDER layer sits above the BACKGROUND sphere texture, ensuring the ring
    -- is always visible regardless of draw order within the same sublayer.
    local petRing = f:CreateTexture(nil, "BORDER")
    petRing:SetTexture("Interface\\AddOns\\Quiver\\Media\\ring")
    petRing:SetPoint("CENTER", f, "CENTER", 0, 0)
    petRing:SetWidth(SPHERE_SIZE)
    petRing:SetHeight(SPHERE_SIZE)
    petRing:SetVertexColor(0.3, 0.3, 0.3, 0)
    self.petRing = petRing


    f:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Quiver", 1, 0.82, 0)
        local pet = Quiver.Modules.Pet
        if pet.dead then
            GameTooltip:AddLine("Right-click: Revive Pet", 1, 0.3, 0.3)
        elseif not pet.exists and GetSpellInfo("Call Pet") then
            GameTooltip:AddLine("Right-click: Call Pet", 0.8, 1.0, 0.4)
        else
            local sp     = Quiver.db.profile.sphere
            local lcType = sp.leftType  or "spell"
            local rcType = sp.rightType or "spell"
            local lcLabel = BindingLabel(lcType, sp.leftClick,  sp.leftMacro)
            local rcLabel = BindingLabel(rcType, sp.rightClick, sp.rightMacro)
            if lcLabel then GameTooltip:AddLine("Left-click: "  .. lcLabel, 1, 1, 1) end
            if rcLabel then GameTooltip:AddLine("Right-click: " .. rcLabel, 1, 1, 1) end
        end
        GameTooltip:AddLine("Middle-click: Drag", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Alt+Right-click: Settings", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f:SetScript("PostClick", function(_, button)
        Sphere:TriggerClickAnim()
        if button == "RightButton" and IsAltKeyDown() then
            Quiver.UI.Config:Toggle()
            return
        end
        local sp = Quiver.db.profile.sphere
        if button == "LeftButton" and not HasBinding(sp.leftType or "spell", sp.leftClick, sp.leftMacro) then
            UIErrorsFrame:AddMessage("Quiver: No left-click action set  \226\128\148  Alt+Right-click to configure", 1, 0.82, 0)
        elseif button == "RightButton" and not HasBinding(sp.rightType or "spell", sp.rightClick, sp.rightMacro) then
            local pet = Quiver.Modules.Pet
            if pet.exists and not pet.dead then
                UIErrorsFrame:AddMessage("Quiver: No right-click action set  \226\128\148  Alt+Right-click to configure", 1, 0.82, 0)
            end
        end
    end)

    -- Ripple ring that expands outward on sphere click
    local ripple = f:CreateTexture(nil, "OVERLAY")
    ripple:SetTexture("Interface\\AddOns\\Quiver\\Media\\ring")
    ripple:SetPoint("CENTER", f, "CENTER", 0, 0)
    ripple:SetWidth(SPHERE_SIZE)
    ripple:SetHeight(SPHERE_SIZE)
    ripple:SetAlpha(0)
    self.ripple     = ripple
    self.rippleT    = nil
    self.rippleDur  = 0.35

    self.pulseColor = nil
    self.frame = f
    self:SetupDrag(f)
    self:SetupMenuButtons(f)
    self:UpdateOnClick()

    f:Show()

    -- Auto-shot bar below the sphere
    local barBg = CreateFrame("Frame", nil, UIParent)
    barBg:SetWidth(BAR_WIDTH)
    barBg:SetHeight(6)
    -- Stings button sits at 270° (radius 59): its bottom edge is 32px below the
    -- sphere frame's bottom. Push the bar below it with an 8px gap → -40.
    barBg:SetPoint("TOP", f, "BOTTOM", 0, -40)
    local barBgTex = barBg:CreateTexture(nil, "BACKGROUND")
    barBgTex:SetAllPoints(barBg)
    barBgTex:SetTexture(0.1, 0.1, 0.1, 0.7)
    local barFill = barBg:CreateTexture(nil, "ARTWORK")
    barFill:SetTexture(1, 1, 1, 1)
    barFill:SetVertexColor(BAR_COLOR_NORMAL[1], BAR_COLOR_NORMAL[2], BAR_COLOR_NORMAL[3], 1)
    barFill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    barFill:SetHeight(6)
    barFill:SetWidth(0)
    local capL = barBg:CreateTexture(nil, "OVERLAY")
    capL:SetTexture(1, 1, 1, 1)
    capL:SetVertexColor(BAR_COLOR_NORMAL[1], BAR_COLOR_NORMAL[2], BAR_COLOR_NORMAL[3], 0.9)
    capL:SetSize(2, 10)
    capL:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    local capR = barBg:CreateTexture(nil, "OVERLAY")
    capR:SetTexture(1, 1, 1, 1)
    capR:SetVertexColor(BAR_COLOR_NORMAL[1], BAR_COLOR_NORMAL[2], BAR_COLOR_NORMAL[3], 0.9)
    capR:SetSize(2, 10)
    capR:SetPoint("RIGHT", barBg, "RIGHT", 0, 0)
    self.autoShotBar   = barBg
    self.autoShotFill  = barFill
    self.autoShotCapL  = capL
    self.autoShotCapR  = capR
    barBg:Hide()
    _autoShotMod = Quiver.Modules.AutoShot

    -- Separate plain frame for animation — SecureActionButtonTemplate can block OnUpdate
    local ticker = CreateFrame("Frame", nil, UIParent)
    ticker:SetScript("OnUpdate", function(_, dt)
        Sphere:_UpdatePulse()
        Sphere:_UpdateRipple(dt)
        Sphere:_UpdateAutoShotBar(dt)
        Sphere:_UpdatePetRingPulse()
    end)
    self.ticker = ticker
end

function Sphere:SetupDrag(f)
    f:SetMovable(true)
    f:RegisterForDrag("MiddleButton")
    f:SetScript("OnDragStart", function(frame)
        if not Quiver.db.profile.sphere.locked and not InCombatLockdown() then
            frame:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local _, _, _, x, y = frame:GetPoint()
        Quiver.db.profile.sphere.x = x
        Quiver.db.profile.sphere.y = y
        if not InCombatLockdown() then
            Quiver.UI.Menus:RebuildAll()
        end
    end)
end

function Sphere:SetupMenuButtons(f)
    -- Representative spell for each section — icon pulled from GetSpellInfo
    -- 7 buttons evenly spaced at 360/7 ≈ 51.4° intervals starting at 0°.
    local buttons = {
        { name = "tank",     angle = 0,   spell = "Growl"             },
        { name = "pet",      angle = 51,  spell = "Call Pet"          },
        { name = "aspects",  angle = 103, spell = "Aspect of the Hawk"},
        { name = "tracking", angle = 154, spell = "Track Beasts"      },
        { name = "traps",    angle = 206, spell = "Frost Trap"        },
        { name = "stings",   angle = 257, spell = "Serpent Sting"     },
        { name = "food",     angle = 309, spell = "Feed Pet"          },
    }

    local BTN_SIZE = 26
    local radius = SPHERE_SIZE / 2 + BTN_SIZE / 2 + 6
    local keydown = GetCVarBool("ActionButtonUseKeyDown")
    for _, btn in ipairs(buttons) do
        local b = CreateFrame("Button", "QuiverBtn_"..btn.name, f, "SecureActionButtonTemplate")
        b:SetWidth(BTN_SIZE)
        b:SetHeight(BTN_SIZE)
        local rad = math.rad(btn.angle)
        b:SetPoint("CENTER", f, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius)
        b:RegisterForClicks(keydown and "AnyDown" or "AnyUp")

        -- Icon from spell, fallback to empty slot; store hint for later restore
        local _, _, icon = GetSpellInfo(btn.spell)
        b.spellHint = btn.spell
        b:SetNormalTexture(icon or "Interface\\Buttons\\UI-Quickslot2")
        b:SetPushedTexture(icon or "Interface\\Buttons\\UI-Quickslot-Depress")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

        if btn.name == "aspects" then
            -- Small corner badge showing the swap-target aspect icon.
            -- Visible at a glance once two aspects are selected.
            local badge = b:CreateTexture(nil, "OVERLAY")
            badge:SetSize(14, 14)
            badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
            badge:Hide()
            b.swapBadge = badge
        end

        if btn.name == "food" then
            local countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            countText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, 2)
            countText:SetTextColor(1, 1, 1)
            b.countText = countText
            b:SetAttribute("type2", "macro")
            b:SetAttribute("macrotext2", "")
        end

        if btn.name == "traps" then
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

        local menuName = btn.name
        if btn.name == "tank" then
            b:SetScript("PostClick", function(_, button)
                if button == "LeftButton" then
                    Quiver.Modules.Pet:ToggleTankMode()
                elseif button == "RightButton" then
                    Quiver.UI.Menus:HideAll()
                end
            end)
            b:SetScript("OnEnter", function(frame)
                local on = Quiver.db and Quiver.db.profile.petTankMode
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Tank Mode: " .. (on and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
                GameTooltip:AddLine(on and "Growl on  \xE2\x80\x93  BW includes Intimidation"
                                       or "Growl off  \xE2\x80\x93  BW excludes Intimidation", 0.6, 0.6, 0.6)
                GameTooltip:AddLine("Click to toggle", 0.4, 0.8, 1.0)
                GameTooltip:Show()
            end)
        elseif btn.name == "food" then
            b:SetScript("PostClick", function(_, button)
                if button == "LeftButton" then
                    Quiver.UI.Menus:ToggleFoodPicker()
                elseif button == "RightButton" then
                    Quiver.UI.Menus:HideAll()
                end
            end)
            b:SetScript("OnEnter", function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Feed Pet")
                local happiness = Quiver.Modules.Pet.happiness
                if happiness == 3 then
                    GameTooltip:AddLine("Pet is already happy!", 0.2, 1.0, 0.2)
                end
                GameTooltip:AddLine("Left-click: open food picker", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
        else
            b:SetScript("PostClick", function(_, button)
                if button == "LeftButton" then
                    Quiver.UI.Menus:Toggle(menuName)
                elseif button == "RightButton" then
                    Quiver.UI.Menus:HideAll()
                end
            end)
            b:SetScript("OnEnter", function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:AddLine(btn.name:sub(1,1):upper()..btn.name:sub(2))
                GameTooltip:AddLine("Left-click: open menu", 0.6, 0.6, 0.6)
                GameTooltip:AddLine("Right-click: cast selected", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
        end
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end

function Sphere:UpdateOnClick()
    local f = self.frame
    if not f or InCombatLockdown() then return end

    local sp     = Quiver.db.profile.sphere
    local lc     = sp.leftClick
    local rc     = sp.rightClick
    local lcType = sp.leftType  or "spell"
    local rcType = sp.rightType or "spell"

    f:SetAttribute("type", nil)
    f:SetAttribute("macrotext", nil)
    f:SetAttribute("type2", "macro")
    f:SetAttribute("macrotext2", "")
    f:SetAttribute("alt-type2", nil)
    f:SetAttribute("alt-macrotext2", nil)
    f:SetAttribute("type3", "macro")
    f:SetAttribute("macrotext3", "")

    if lcType == "spell" and lc ~= "none" then
        f:SetAttribute("type", "macro")
        f:SetAttribute("macrotext", "/cast " .. lc)
    elseif lcType == "macro" and (sp.leftMacro or "") ~= "" then
        f:SetAttribute("type", "macro")
        f:SetAttribute("macrotext", sp.leftMacro)
    end

    local petRevive = GetSpellInfo("Revive Pet")
    local petCall   = GetSpellInfo("Call Pet")

    if petCall then
        -- Bake pet emergency into the macro so conditions evaluate at click-time.
        -- This works inside combat lockdown because WoW tests conditionals when the
        -- button is pressed, not when SetAttribute was last called.
        local lines = {}
        if petRevive then
            lines[#lines+1] = "/cast [@pet,dead] Revive Pet"
        end
        lines[#lines+1] = "/cast [nopet] Call Pet"
        if rcType == "spell" and rc ~= "none" then
            lines[#lines+1] = "/cast [pet,nodead] " .. rc
        elseif rcType == "macro" and (sp.rightMacro or "") ~= "" then
            -- Stop macro execution if pet is dead or missing so the user's
            -- configured macro doesn't fire alongside Revive/Call Pet.
            lines[#lines+1] = "/stopmacro [@pet,dead][nopet]"
            lines[#lines+1] = sp.rightMacro
        end
        f:SetAttribute("macrotext2", table.concat(lines, "\n"))
        f:SetAttribute("alt-type2", "macro")
        f:SetAttribute("alt-macrotext2", "")
    else
        if rcType == "spell" and rc ~= "none" then
            f:SetAttribute("macrotext2", "/cast " .. rc)
            f:SetAttribute("alt-type2", "macro")
            f:SetAttribute("alt-macrotext2", "")
        elseif rcType == "macro" and (sp.rightMacro or "") ~= "" then
            f:SetAttribute("macrotext2", sp.rightMacro)
            f:SetAttribute("alt-type2", "macro")
            f:SetAttribute("alt-macrotext2", "")
        end
    end
end

function Sphere:Show()
    if self.frame then self.frame:Show() end
end

function Sphere:Hide()
    if self.frame then self.frame:Hide() end
end

function Sphere:_UpdatePulse()
    if not self.pulseColor or not self.overlay then return end
    local alpha = (math.sin(GetTime() * math.pi) + 1) / 2 * 0.7
    local c = self.pulseColor
    self.overlay:SetVertexColor(c[1], c[2], c[3], alpha)
end

function Sphere:UpdateColor()
    local current = Quiver.Modules.Aspects.current
    local onViper = current and current.name == "Aspect of the Viper"
    local manaLow = Quiver.Modules.Mana and Quiver.Modules.Mana.isLow

    if manaLow and not onViper then
        -- Blue pulse: mana low, switch to Viper
        self.pulseColor = PULSE_COLOR_MANA_LOW
    elseif not current then
        -- Maroon pulse: no aspect active
        self.pulseColor = PULSE_COLOR_NO_ASPECT
    else
        -- Aspect active, mana fine: show aspect tint
        self.pulseColor = nil
        local r, g, b = Quiver.Modules.Aspects:GetCurrentColor()
        if self.overlay then
            self.overlay:SetVertexColor(r, g, b, 0.6)
        end
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
    if not self.petRing then return end
    local pet = Quiver.Modules.Pet
    if pet.exists and not pet.dead then
        local r, g, b = pet:GetHappinessColor()
        self.petRing:SetVertexColor(r, g, b, 0.85)
    end
    -- Dead and no-pet pulse states are driven each frame by _UpdatePetRingPulse.
end

function Sphere:_UpdatePetRingPulse()
    if not self.petRing then return end
    local pet = Quiver.Modules.Pet
    if pet.dead then
        local alpha = (math.sin(GetTime() * math.pi * 1.5) + 1) / 2 * 0.85
        self.petRing:SetVertexColor(0.9, 0.1, 0.1, alpha)
    elseif not pet.exists and GetSpellInfo("Call Pet") then
        local alpha = (math.sin(GetTime() * math.pi * 0.8) + 1) / 2 * 0.5
        self.petRing:SetVertexColor(0.8, 0.4, 0.0, alpha)
    elseif not pet.exists then
        self.petRing:SetVertexColor(0, 0, 0, 0)
    end
end

function Sphere:UpdateTrackingIndicator()
    local btn = _G["QuiverBtn_tracking"]
    if not btn then return end
    local current = Quiver.Modules.Tracking.current
    if current then
        -- GetTrackingTexture returns a file path string — safe to use directly
        btn:SetNormalTexture(current)
        btn:SetPushedTexture(current)
    else
        -- No active tracking: restore the hint icon
        local _, _, hintIcon = GetSpellInfo(btn.spellHint or "Track Beasts")
        btn:SetNormalTexture(hintIcon or "Interface\\Buttons\\UI-Quickslot2")
        btn:SetPushedTexture(hintIcon or "Interface\\Buttons\\UI-Quickslot-Depress")
    end
end

function Sphere:TriggerClickAnim()
    self.rippleT = 0
end

function Sphere:_UpdateRipple(dt)
    if self.rippleT == nil then return end
    self.rippleT = self.rippleT + dt
    local progress = self.rippleT / self.rippleDur
    if progress >= 1 then
        self.rippleT = nil
        self.ripple:SetAlpha(0)
        self.ripple:SetWidth(SPHERE_SIZE)
        self.ripple:SetHeight(SPHERE_SIZE)
        return
    end
    self.ripple:SetWidth(SPHERE_SIZE * (1 + progress * 1.5))
    self.ripple:SetHeight(SPHERE_SIZE * (1 + progress * 1.5))
    self.ripple:SetAlpha(0.75 * (1 - progress))
end

function Sphere:UpdateAutoShotBar()
    if not self.autoShotBar then return end
    if _autoShotMod and _autoShotMod:ShouldShow() then
        self.autoShotBar:Show()
    else
        self.autoShotBar:Hide()
    end
end

function Sphere:UpdateAutoShotBarColor(boosted)
    if not self.autoShotFill then return end
    local c = boosted and BAR_COLOR_HASTE or BAR_COLOR_NORMAL
    self.autoShotFill:SetVertexColor(c[1], c[2], c[3], 1)
    self.autoShotCapL:SetVertexColor(c[1], c[2], c[3], 0.9)
    self.autoShotCapR:SetVertexColor(c[1], c[2], c[3], 0.9)
end

function Sphere:_UpdateAutoShotBar(dt)
    if not _autoShotMod or not self.autoShotFill then return end
    _autoShotMod:Tick(dt)
    if not self.autoShotBar:IsShown() then return end
    local progress = _autoShotMod:GetProgress()
    local w = BAR_WIDTH * progress
    if w < 0 then w = 0 end
    self.autoShotFill:SetWidth(w)
end
