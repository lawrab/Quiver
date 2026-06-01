local loader = require("tests.loader")
loader.setup({ "Modules/Pet.lua" })

local Pet = Quiver.Modules.Pet

describe("Pet:Initialize", function()
    it("starts with no pet, not dead, no happiness", function()
        Pet:Initialize()
        assert.is_false(Pet.exists)
        assert.is_false(Pet.dead)
        assert.is_nil(Pet.happiness)
    end)
end)

describe("Pet:UpdateState", function()
    before_each(function()
        Pet:Initialize()
        _G._petExists    = false
        _G._petDead      = false
        _G._petHappiness = 3
        _G._soundsPlayed = {}
        Quiver.db.profile.notifications.petDied = false
        Quiver.db.profile.sounds.petUnhappy     = false
    end)

    it("reflects no pet when unit does not exist", function()
        _G._petExists = false
        Pet:UpdateState()
        assert.is_false(Pet.exists)
        assert.is_false(Pet.dead)
        assert.is_nil(Pet.happiness)
    end)

    it("reflects live happy pet", function()
        _G._petExists    = true
        _G._petDead      = false
        _G._petHappiness = 3
        Pet:UpdateState()
        assert.is_true(Pet.exists)
        assert.is_false(Pet.dead)
        assert.equals(3, Pet.happiness)
    end)

    it("reflects dead pet", function()
        _G._petExists = true
        _G._petDead   = true
        Pet:UpdateState()
        assert.is_true(Pet.exists)
        assert.is_true(Pet.dead)
    end)

    it("prints death notification on first dead transition when enabled", function()
        Quiver.db.profile.notifications.petDied = true
        _G._petExists = true
        _G._petDead   = false
        Pet:UpdateState()        -- alive

        local printed = {}
        local orig = _G.print
        _G.print = function(s) table.insert(printed, s) end

        _G._petDead = true
        Pet:UpdateState()        -- dies

        _G.print = orig
        assert.equals(1, #printed)
        assert.truthy(printed[1]:find("pet died"))
    end)

    it("does not print death notification on subsequent ticks while dead", function()
        Quiver.db.profile.notifications.petDied = true
        _G._petExists = true
        _G._petDead   = true
        Pet:UpdateState()        -- first tick — pet already dead from Initialize baseline

        local count = 0
        local orig = _G.print
        _G.print = function() count = count + 1 end
        Pet:UpdateState()        -- second tick — still dead
        _G.print = orig
        assert.equals(0, count)
    end)

    it("does not print death notification when disabled", function()
        Quiver.db.profile.notifications.petDied = false
        _G._petExists = true
        _G._petDead   = false
        Pet:UpdateState()

        local printed = {}
        local orig = _G.print
        _G.print = function(s) table.insert(printed, s) end
        _G._petDead = true
        Pet:UpdateState()
        _G.print = orig
        assert.equals(0, #printed)
    end)

    it("plays unhappy sound on happiness 1 when enabled", function()
        Quiver.db.profile.sounds.petUnhappy = true
        _G._petExists    = true
        _G._petHappiness = 1
        Pet:UpdateState()
        assert.equals(1, #_G._soundsPlayed)
    end)

    it("does not play unhappy sound when disabled", function()
        Quiver.db.profile.sounds.petUnhappy = false
        _G._petExists    = true
        _G._petHappiness = 1
        Pet:UpdateState()
        assert.equals(0, #_G._soundsPlayed)
    end)

    it("does not play unhappy sound when pet is happy", function()
        Quiver.db.profile.sounds.petUnhappy = true
        _G._petExists    = true
        _G._petHappiness = 3
        Pet:UpdateState()
        assert.equals(0, #_G._soundsPlayed)
    end)

    it("clears dead flag when pet disappears", function()
        _G._petExists = true
        _G._petDead   = true
        Pet:UpdateState()
        assert.is_true(Pet.dead)

        _G._petExists = false
        Pet:UpdateState()
        assert.is_false(Pet.dead)
    end)
end)

describe("Pet:GetHappinessColor", function()
    before_each(function() Pet:Initialize() end)

    it("returns red for unhappy (1)", function()
        Pet.happiness = 1
        local r, g, b = Pet:GetHappinessColor()
        assert.near(1.0, r, 0.01)
        assert.near(0.2, g, 0.01)
    end)

    it("returns yellow for content (2)", function()
        Pet.happiness = 2
        local r, g, b = Pet:GetHappinessColor()
        assert.near(1.0, r, 0.01)
        assert.near(0.8, g, 0.01)
    end)

    it("returns green for happy (3)", function()
        Pet.happiness = 3
        local r, g, b = Pet:GetHappinessColor()
        assert.near(0.2, r, 0.01)
        assert.near(1.0, g, 0.01)
    end)

    it("returns grey when happiness is nil", function()
        Pet.happiness = nil
        local r, g, b = Pet:GetHappinessColor()
        assert.near(0.5, r, 0.01)
        assert.near(0.5, g, 0.01)
        assert.near(0.5, b, 0.01)
    end)
end)
