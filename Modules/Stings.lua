-- Tracks active sting on current target; only one sting active at a time

local Stings = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Stings = Stings

local STINGS = {
    { name = "Serpent Sting", duration = 15 },
    { name = "Viper Sting",   duration = 8  },
    { name = "Scorpid Sting", duration = 20 },
    { name = "Wyvern Sting",  duration = 6  },
}
Stings.STINGS = STINGS

function Stings:Initialize()
    self.active = nil
    self.expires = 0
end

function Stings:Enable()
    Quiver:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "target" then self:ScanTarget() end
    end)
    Quiver:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:ScanTarget() end)
    self:ScanTarget()
end

function Stings:ScanTarget()
    self.active = nil
    self.expires = 0

    if not UnitExists("target") then return end

    for i = 1, 40 do
        local name, _, _, _, _, duration, expirationTime, unitCaster = UnitDebuff("target", i)
        if not name then break end
        if unitCaster == "player" then
            for _, sting in ipairs(STINGS) do
                if name == sting.name then
                    self.active = sting
                    self.expires = expirationTime
                    break
                end
            end
        end
        if self.active then break end
    end

    Quiver.UI.Sphere:UpdateStingDisplay()
end

function Stings:GetTimeRemaining()
    if self.expires == 0 then return 0 end
    return math.max(0, self.expires - GetTime())
end

function Stings:Cast(stingName)
    CastSpellByName(stingName)
end
