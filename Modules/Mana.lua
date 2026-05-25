-- Tracks player mana and flags when it's low enough to nudge switching to Viper.

local Mana = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Mana = Mana

local THRESHOLD = 0.30   -- pulse below 30 % mana

Mana.isLow = false

function Mana:Initialize()
    self.isLow = false
end

function Mana:Enable()
    Quiver:RegisterEvent("UNIT_MANA", function(_, unit)
        if unit == "player" then self:Check() end
    end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:Check() end)
    self:Check()

    local elapsed = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 2.0 then
            elapsed = 0
            self:Check()
        end
    end)
end

function Mana:Check()
    local max = UnitManaMax("player")
    if not max or max == 0 then return end
    local pct = UnitMana("player") / max
    local wasLow = self.isLow
    self.isLow = pct < THRESHOLD
    if self.isLow ~= wasLow then
        Quiver.UI.Sphere:UpdateColor()
    end
end
