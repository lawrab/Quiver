-- Pet state tracking: happiness, health, existence

local Pet = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Pet = Pet

local HAPPINESS_COLORS = {
    [1] = {1.0, 0.2, 0.2}, -- unhappy: red
    [2] = {1.0, 0.8, 0.0}, -- content: yellow
    [3] = {0.2, 1.0, 0.2}, -- happy: green
}

function Pet:Initialize()
    self.happiness = nil
    self.exists = false
end

function Pet:Enable()
    Quiver:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then self:UpdateState() end
    end)
    Quiver:RegisterEvent("UNIT_HAPPINESS", function(_, unit)
        if unit == "pet" then self:UpdateState() end
    end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:UpdateState() end)
    self:UpdateState()
end

function Pet:UpdateState()
    self.exists = UnitExists("pet")
    if self.exists then
        self.happiness = GetPetHappiness()
    else
        self.happiness = nil
    end
    Quiver.UI.Sphere:UpdatePetIndicator()

    if self.happiness == 1 and Quiver.db.profile.sounds.ammoLow then
        -- PlaySoundFile("Interface\\AddOns\\Quiver\\Media\\Sounds\\pet_unhappy.ogg")
    end
end

function Pet:GetHappinessColor()
    if self.happiness then
        return unpack(HAPPINESS_COLORS[self.happiness] or HAPPINESS_COLORS[2])
    end
    return 0.5, 0.5, 0.5
end

function Pet:CallPet()   CastSpellByName("Call Pet")    end
function Pet:DismissPet() CastSpellByName("Dismiss Pet") end
function Pet:RevivePet() CastSpellByName("Revive Pet")  end
function Pet:MendPet()   CastSpellByName("Mend Pet")    end
