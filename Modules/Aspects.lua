-- Tracks active Aspect and provides quick-cast
-- Aspects in TBC Anniversary are regular buffs (not shapeshift forms)

local Aspects = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Aspects = Aspects

local ASPECTS = {
    { name = "Aspect of the Hawk",       color = {0.2, 0.8, 0.2} },
    { name = "Aspect of the Viper",      color = {0.3, 0.5, 1.0} },
    { name = "Aspect of the Cheetah",    color = {1.0, 0.8, 0.0} },
    { name = "Aspect of the Pack",       color = {0.8, 0.6, 0.2} },
    { name = "Aspect of the Wild",       color = {0.0, 0.9, 0.4} },
    { name = "Aspect of the Monkey",     color = {0.8, 0.4, 0.0} },
    { name = "Aspect of the Dragonhawk", color = {0.9, 0.3, 0.1} },
}
Aspects.ASPECTS = ASPECTS

local ASPECTS_BY_NAME = {}
for _, a in ipairs(ASPECTS) do ASPECTS_BY_NAME[a.name] = a end

-- Default sphere color when no aspect is active
Aspects.DEFAULT_COLOR = {0.5, 0.5, 0.5}

function Aspects:Initialize()
    self.current = nil
end

function Aspects:Enable()
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:DetectCurrentAspect() end)
    -- Use a raw WoW frame so UNIT_AURA and UPDATE_SHAPESHIFT_FORM are independent
    -- of any other AceEvent registrations on the Quiver object (AceEvent keys
    -- handlers by (addon_object, event), so two RegisterEvent calls for the same
    -- event on the same object would silently overwrite each other).
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit ~= "player" then return end
            -- Only scan when the player casts an aspect spell.
            local name = spellID and GetSpellInfo(spellID)
            if not (name and ASPECTS_BY_NAME[name]) then return end
        end
        self:DetectCurrentAspect()
    end)
    self._eventFrame = f
    self:DetectCurrentAspect()
end

function Aspects:Disable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:SetScript("OnEvent", nil)
    end
end

function Aspects:DetectCurrentAspect()
    self.current = nil

    -- Aspects are shapeshifts in TBC; use the shapeshift API as primary source.
    -- GetShapeshiftFormInfo returns icon, active, castable, spellID (no name).
    local formIndex = GetShapeshiftForm()
    if formIndex and formIndex > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID then
            local name = GetSpellInfo(spellID)
            if name then
                self.current = ASPECTS_BY_NAME[name]
                -- Cache form index by name so ApplySelectionToTrigger can build
                -- a [stance:N] conditional without needing GetNumShapeshiftForms().
                if not self.formIndex then self.formIndex = {} end
                self.formIndex[name] = formIndex
            end
        end
    end

    -- Fallback: UnitBuff scan in case aspects surface as regular buffs on this client.
    if not self.current then
        local i = 1
        while true do
            local name = UnitBuff("player", i)
            if not name then break end
            local aspect = ASPECTS_BY_NAME[name]
            if aspect then self.current = aspect; break end
            i = i + 1
        end
    end

    Quiver.UI.Sphere:UpdateColor()

    -- SetNormalTexture and Texture:SetTexture are not combat-restricted; update the orbit
    -- button icon and swap badge immediately so they track the live aspect during combat.
    local triggerBtn = _G["QuiverBtn_aspects"]
    if triggerBtn and self.current then
        local _, _, icon = GetSpellInfo(self.current.name)
        if icon then
            triggerBtn:SetNormalTexture(icon)
            triggerBtn:SetPushedTexture(icon)
        end
        local menu = Quiver.UI.Menus and Quiver.UI.Menus.menus and Quiver.UI.Menus.menus.aspects
        local badge = triggerBtn.swapBadge
        if badge and menu and menu.selected and menu.otherSelected then
            local badgeTarget = (self.current.name == menu.selected.spell)
                and menu.otherSelected.spell
                or menu.selected.spell
            local _, _, badgeIcon = GetSpellInfo(badgeTarget)
            if badgeIcon then
                badge:SetTexture(badgeIcon)
                badge:Show()
            else
                badge:Hide()
            end
        end
    end

    -- SetAttribute is combat-restricted; defer macro/attribute update to out-of-combat.
    if not InCombatLockdown() and Quiver.UI.Menus and Quiver.UI.Menus.menus then
        Quiver.UI.Menus:ApplySelectionToTrigger(Quiver.UI.Menus.menus.aspects)
    end

end

function Aspects:GetCurrentColor()
    if self.current then
        return unpack(self.current.color)
    end
    return unpack(Aspects.DEFAULT_COLOR)
end

