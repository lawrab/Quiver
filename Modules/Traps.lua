-- Trap cooldown tracking

local Traps = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Traps = Traps

local TRAPS = {
    { name = "Frost Trap"      },
    { name = "Freezing Trap"   },
    { name = "Immolation Trap" },
    { name = "Explosive Trap"  },
    { name = "Snake Trap"      },
}
Traps.TRAPS = TRAPS

function Traps:Initialize()
    self.cooldowns = {}
    for _, trap in ipairs(TRAPS) do
        self.cooldowns[trap.name] = { start = 0, duration = 0 }
    end
end

function Traps:Enable()
    Quiver:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    self:UpdateCooldowns()
end

function Traps:UpdateCooldowns()
    for _, trap in ipairs(TRAPS) do
        local start, duration = GetSpellCooldown(trap.name)
        local cd = self.cooldowns[trap.name]
        cd.start    = start    or 0
        cd.duration = duration or 0
    end
    Quiver.UI.Menus:UpdateTrapCooldowns()
end

function Traps:GetCooldown(trapName)
    local cd = self.cooldowns[trapName]
    if not cd or cd.duration == 0 then return 0 end
    return math.max(0, cd.start + cd.duration - GetTime())
end

