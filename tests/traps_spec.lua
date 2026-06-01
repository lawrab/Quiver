local loader = require("tests.loader")
loader.setup({ "Modules/Traps.lua" })

local Traps = Quiver.Modules.Traps

describe("Traps:GetCooldown", function()
    before_each(function()
        Traps:Initialize()
        _G._time = 100
        _G._spellCooldowns = {}
    end)

    it("returns 0 when no cooldown is active", function()
        _G._spellCooldowns["Frost Trap"] = 0
        Traps:UpdateCooldowns()
        assert.equals(0, Traps:GetCooldown("Frost Trap"))
    end)

    it("returns remaining time when cooldown is active", function()
        -- start=95, duration=30 → expires at 125; at t=100 → 25 remaining
        _G._spellCooldowns["Frost Trap"] = 95
        Traps.cooldowns["Frost Trap"] = { start = 95, duration = 30 }
        _G._time = 100
        assert.near(25, Traps:GetCooldown("Frost Trap"), 0.01)
    end)

    it("returns 0 when cooldown has already expired", function()
        -- start=80, duration=10 → expired at 90; at t=100 → 0
        Traps.cooldowns["Freezing Trap"] = { start = 80, duration = 10 }
        _G._time = 100
        assert.equals(0, Traps:GetCooldown("Freezing Trap"))
    end)

    it("returns 0 for unknown trap name", function()
        assert.equals(0, Traps:GetCooldown("Nonexistent Trap"))
    end)

    it("clamps to 0, never returns negative", function()
        Traps.cooldowns["Snake Trap"] = { start = 50, duration = 20 }
        _G._time = 200  -- way past expiry
        assert.equals(0, Traps:GetCooldown("Snake Trap"))
    end)

    it("UpdateCooldowns populates all five traps", function()
        for _, trap in ipairs(Traps.TRAPS) do
            _G._spellCooldowns[trap.name] = 0
        end
        Traps:UpdateCooldowns()
        for _, trap in ipairs(Traps.TRAPS) do
            assert.not_nil(Traps.cooldowns[trap.name])
        end
    end)
end)
