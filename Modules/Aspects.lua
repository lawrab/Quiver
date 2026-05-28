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
    Quiver:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() self:DetectCurrentAspect() end)
    self:DetectCurrentAspect()
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
            if name then self.current = ASPECTS_BY_NAME[name] end
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
end

function Aspects:GetCurrentColor()
    if self.current then
        return unpack(self.current.color)
    end
    return unpack(Aspects.DEFAULT_COLOR)
end

