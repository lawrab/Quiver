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

-- Default sphere color when no aspect is active
Aspects.DEFAULT_COLOR = {0.5, 0.5, 0.5}

function Aspects:Initialize()
    self.current = nil
end

function Aspects:Enable()
    Quiver:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "player" then self:DetectCurrentAspect() end
    end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:DetectCurrentAspect() end)
    self:DetectCurrentAspect()

    -- Poll every second to catch aspect removal; UNIT_AURA doesn't fire
    -- reliably when aspects are cancelled in TBC Classic Anniversary.
    local elapsed = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1.0 then
            elapsed = 0
            self:DetectCurrentAspect()
        end
    end)
end

function Aspects:DetectCurrentAspect()
    self.current = nil
    local i = 1
    while true do
        local name = UnitBuff("player", i)
        if not name then break end
        for _, aspect in ipairs(ASPECTS) do
            if name == aspect.name then
                self.current = aspect
                Quiver.UI.Sphere:UpdateColor()
                return
            end
        end
        i = i + 1
    end
    Quiver.UI.Sphere:UpdateColor()
end

function Aspects:GetCurrentColor()
    if self.current then
        return unpack(self.current.color)
    end
    return unpack(Aspects.DEFAULT_COLOR)
end

