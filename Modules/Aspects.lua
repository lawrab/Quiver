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
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:DetectCurrentAspect() end)
    self:DetectCurrentAspect()

    -- Poll every second; UNIT_AURA is unreliable for aspect detection in
    -- TBC Classic Anniversary and its updateInfo payload creates a new table
    -- on every fire, generating GC pressure at 10-20 fires/sec in combat.
    local elapsed = 0
    self.ticker = CreateFrame("Frame")
    self.ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1.0 then
            elapsed = 0
            self:DetectCurrentAspect()
        end
    end)
end

function Aspects:Disable()
    if self.ticker then self.ticker:Hide() end
end

function Aspects:DetectCurrentAspect()
    local prev = self.current
    self.current = nil
    local i = 1
    while true do
        local name = UnitBuff("player", i)
        if not name then break end
        for _, aspect in ipairs(ASPECTS) do
            if name == aspect.name then
                self.current = aspect
                if self.current ~= prev then
                    Quiver.UI.Sphere:UpdateColor()
                end
                return
            end
        end
        i = i + 1
    end
    -- No aspect found; only update the sphere if the aspect was just removed.
    if prev ~= nil then
        Quiver.UI.Sphere:UpdateColor()
    end
end

function Aspects:GetCurrentColor()
    if self.current then
        return unpack(self.current.color)
    end
    return unpack(Aspects.DEFAULT_COLOR)
end

