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

local STINGS_BY_NAME = {}
for _, s in ipairs(STINGS) do STINGS_BY_NAME[s.name] = s end

function Stings:Initialize()
    self.active = nil
    self.expires = 0
end

function Stings:Enable()
    Quiver:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:ScanTarget() end)
    self:ScanTarget()
    Quiver:RegisterEvent("UNIT_AURA", function(_, unit, updateInfo)
        if unit ~= "target" then return end
        -- updateInfo is nil on older Classic clients; fall through to full scan.
        if updateInfo and not updateInfo.isFullUpdate then
            local relevant = false
            if updateInfo.addedAuras then
                for _, aura in ipairs(updateInfo.addedAuras) do
                    if STINGS_BY_NAME[aura.name] and aura.sourceUnit == "player" then
                        relevant = true; break
                    end
                end
            end
            if not relevant and self.active and updateInfo.removedAuraInstanceIDs then
                relevant = #updateInfo.removedAuraInstanceIDs > 0
            end
            if not relevant then return end
        end
        self:ScanTarget()
    end)
end

function Stings:ScanTarget()
    self.active = nil
    self.expires = 0

    if not UnitExists("target") then return end

    for i = 1, 40 do
        local name, _, _, _, _, duration, expirationTime, unitCaster = UnitDebuff("target", i)
        if not name then break end
        if unitCaster == "player" then
            local sting = STINGS_BY_NAME[name]
            if sting then
                self.active = sting
                self.expires = expirationTime
                break
            end
        end
    end

    Quiver.UI.Sphere:UpdateStingDisplay()
end

function Stings:GetTimeRemaining()
    if self.expires == 0 then return 0 end
    return math.max(0, self.expires - GetTime())
end

