-- Trap cooldown tracking

local Traps = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Traps = Traps

local TRAPS = {
    { name = "Frost Trap",       icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
    { name = "Freezing Trap",    icon = "Interface\\Icons\\Spell_Nature_Stranglevines" },
    { name = "Immolation Trap",  icon = "Interface\\Icons\\Spell_Fire_SealOfFire" },
    { name = "Explosive Trap",   icon = "Interface\\Icons\\Spell_Fire_SelectiveInvisibility" },
    { name = "Snake Trap",       icon = "Interface\\Icons\\Ability_Hunter_SnakeTrap" },
}
Traps.TRAPS = TRAPS

function Traps:Initialize()
    self.cooldowns = {}
end

function Traps:Enable()
    Quiver:RegisterEvent("SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    self:UpdateCooldowns()
end

function Traps:UpdateCooldowns()
    for _, trap in ipairs(TRAPS) do
        local start, duration = GetSpellCooldown(trap.name)
        self.cooldowns[trap.name] = { start = start, duration = duration }
    end
    Quiver.UI.Menus:UpdateTrapCooldowns()
end

function Traps:GetCooldown(trapName)
    local cd = self.cooldowns[trapName]
    if not cd or cd.duration == 0 then return 0 end
    return math.max(0, cd.start + cd.duration - GetTime())
end

function Traps:Cast(trapName)
    CastSpellByName(trapName)
end
