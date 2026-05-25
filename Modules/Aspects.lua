-- Tracks active Aspect and provides quick-cast
-- Aspects in TBC are implemented as shapeshift forms

local Aspects = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Aspects = Aspects

-- Spell IDs for TBC aspects
local ASPECTS = {
    { name = "Aspect of the Hawk",       spellID = 14327, color = {0.2, 0.8, 0.2} },
    { name = "Aspect of the Viper",      spellID = 34074, color = {0.3, 0.5, 1.0} },
    { name = "Aspect of the Cheetah",    spellID = 5118,  color = {1.0, 0.8, 0.0} },
    { name = "Aspect of the Pack",       spellID = 13159, color = {0.8, 0.6, 0.2} },
    { name = "Aspect of the Wild",       spellID = 20043, color = {0.0, 0.9, 0.4} },
    { name = "Aspect of the Monkey",     spellID = 13163, color = {0.8, 0.4, 0.0} },
    { name = "Aspect of the Dragonhawk", spellID = 34076, color = {0.9, 0.3, 0.1} },
}
Aspects.ASPECTS = ASPECTS

-- Default sphere color when no aspect is active
Aspects.DEFAULT_COLOR = {0.5, 0.5, 0.5}

function Aspects:Initialize()
    self.current = nil
end

function Aspects:Enable()
    Quiver:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() self:OnAspectChanged() end)
    self:DetectCurrentAspect()
end

function Aspects:DetectCurrentAspect()
    local numForms = GetNumShapeshiftForms()
    self.current = nil
    for i = 1, numForms do
        local _, active = GetShapeshiftFormInfo(i)
        if active then
            -- match by index since TBC shapeshift order matches ASPECTS
            self.current = ASPECTS[i]
            break
        end
    end
    Quiver.UI.Sphere:UpdateColor()
end

function Aspects:OnAspectChanged()
    self:DetectCurrentAspect()
end

function Aspects:GetCurrentColor()
    if self.current then
        return unpack(self.current.color)
    end
    return unpack(Aspects.DEFAULT_COLOR)
end

function Aspects:Cast(aspectName)
    CastSpellByName(aspectName)
end
