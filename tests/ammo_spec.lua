local loader = require("tests.loader")
loader.setup({ "Modules/Ammo.lua" })

local Ammo = Quiver.Modules.Ammo

describe("Ammo:UpdateCount", function()
    before_each(function()
        Ammo:Initialize()
        _G._ammoCount    = 0
        _G._ammoLink     = nil
        _G._soundsPlayed = {}
        Quiver.db.profile.ammoWarnThreshold = 100
        Quiver.db.profile.sounds.ammoLow    = false
    end)

    it("stores current ammo count", function()
        _G._ammoCount = 250
        Ammo:UpdateCount()
        assert.equals(250, Ammo:GetCount())
    end)

    it("fires OnAmmoLow when crossing below threshold", function()
        local fired = false
        local orig = Ammo.OnAmmoLow
        Ammo.OnAmmoLow = function() fired = true end

        _G._ammoCount = 200
        Ammo:UpdateCount()   -- above threshold, wasLow = false
        assert.is_false(fired)

        _G._ammoCount = 50
        Ammo:UpdateCount()   -- crosses below — should fire
        assert.is_true(fired)

        Ammo.OnAmmoLow = orig
    end)

    it("does not fire OnAmmoLow again while still below threshold", function()
        local count = 0
        local orig = Ammo.OnAmmoLow
        Ammo.OnAmmoLow = function() count = count + 1 end

        _G._ammoCount = 50
        Ammo:UpdateCount()   -- first cross
        Ammo:UpdateCount()   -- still low — no repeat
        assert.equals(1, count)

        Ammo.OnAmmoLow = orig
    end)

    it("resets and fires again after going back above threshold", function()
        local count = 0
        local orig = Ammo.OnAmmoLow
        Ammo.OnAmmoLow = function() count = count + 1 end

        _G._ammoCount = 50
        Ammo:UpdateCount()   -- first cross
        _G._ammoCount = 200
        Ammo:UpdateCount()   -- back above
        _G._ammoCount = 30
        Ammo:UpdateCount()   -- crosses again
        assert.equals(2, count)

        Ammo.OnAmmoLow = orig
    end)

    it("does not fire when count is 0 (no ammo pouch equipped)", function()
        local fired = false
        local orig = Ammo.OnAmmoLow
        Ammo.OnAmmoLow = function() fired = true end

        _G._ammoCount = 0
        Ammo:UpdateCount()
        assert.is_false(fired)

        Ammo.OnAmmoLow = orig
    end)
end)

describe("Ammo:OnAmmoLow", function()
    before_each(function()
        _G._soundsPlayed = {}
        Quiver.db.profile.sounds.ammoLow = false
    end)

    it("plays sound when ammoLow is enabled", function()
        Quiver.db.profile.sounds.ammoLow = true
        Ammo:OnAmmoLow()
        assert.equals(1, #_G._soundsPlayed)
    end)

    it("does not play sound when ammoLow is disabled", function()
        Quiver.db.profile.sounds.ammoLow = false
        Ammo:OnAmmoLow()
        assert.equals(0, #_G._soundsPlayed)
    end)
end)
