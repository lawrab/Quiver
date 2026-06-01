local loader = require("tests.loader")
loader.setup({ "Modules/Aspects.lua" })

local Aspects = Quiver.Modules.Aspects

-- Helper: prime GetSpellInfo to return a spell name for a given ID
local function stub_spell(id, name)
    _G._spellInfo[tostring(id)] = { name, "", 134400 }
end

describe("Aspects:DetectCurrentAspect", function()
    before_each(function()
        Aspects:Initialize()
        _G._spellInfo = {}
        -- Default: no shapeshift form active
        -- Use _G explicitly: busted sandboxes spec files via setfenv so bare
        -- assignments only update the spec's local env, not the real _G that
        -- loaded module code reads.
        _G.GetShapeshiftForm      = function() return 0 end
        _G.GetShapeshiftFormInfo  = function() return nil end
        _G.UnitBuff               = function() return nil end
    end)

    it("sets current to nil when no aspect is active", function()
        Aspects:DetectCurrentAspect()
        assert.is_nil(Aspects.current)
    end)

    it("detects aspect via shapeshift form", function()
        stub_spell(13165, "Aspect of the Hawk")
        _G.GetShapeshiftForm     = function() return 1 end
        _G.GetShapeshiftFormInfo = function(_) return nil, nil, nil, 13165 end
        Aspects:DetectCurrentAspect()
        assert.not_nil(Aspects.current)
        assert.equals("Aspect of the Hawk", Aspects.current.name)
    end)

    it("falls back to UnitBuff scan when shapeshift returns 0", function()
        local buffs = { "Aspect of the Viper" }
        _G.GetShapeshiftForm = function() return 0 end
        _G.UnitBuff = function(_, i) return buffs[i] end
        Aspects:DetectCurrentAspect()
        assert.not_nil(Aspects.current)
        assert.equals("Aspect of the Viper", Aspects.current.name)
    end)

    it("ignores unknown buff names in the scan", function()
        _G.UnitBuff = function(_, i)
            if i == 1 then return "Some Other Buff" end
            return nil
        end
        Aspects:DetectCurrentAspect()
        assert.is_nil(Aspects.current)
    end)

    it("sets current to nil when shapeshift spell is unrecognised", function()
        stub_spell(99999, "Unknown Shapeshift")
        _G.GetShapeshiftForm     = function() return 1 end
        _G.GetShapeshiftFormInfo = function(_) return nil, nil, nil, 99999 end
        Aspects:DetectCurrentAspect()
        assert.is_nil(Aspects.current)
    end)
end)

describe("Aspects:GetCurrentColor", function()
    before_each(function() Aspects:Initialize() end)

    it("returns default grey when no aspect active", function()
        Aspects.current = nil
        local r, g, b = Aspects:GetCurrentColor()
        assert.near(Aspects.DEFAULT_COLOR[1], r, 0.01)
        assert.near(Aspects.DEFAULT_COLOR[2], g, 0.01)
        assert.near(Aspects.DEFAULT_COLOR[3], b, 0.01)
    end)

    it("returns aspect color when active", function()
        Aspects.current = Aspects.ASPECTS[1]  -- Hawk: {0.2, 0.8, 0.2}
        local r, g, b = Aspects:GetCurrentColor()
        assert.near(0.2, r, 0.01)
        assert.near(0.8, g, 0.01)
        assert.near(0.2, b, 0.01)
    end)
end)
