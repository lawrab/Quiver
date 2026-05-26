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
    Quiver.UI.Menus:RebuildFoodPicker()

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

function Pet:GetSuitableFood()
    if not self.exists then return {} end

    local foodTypes = {}
    for _, ft in ipairs({GetPetFoodTypes()}) do
        foodTypes[ft] = true
    end
    if not next(foodTypes) then return {} end

    local db = Quiver.Data.PetFoods
    local petBuffIDs = db.petBuffIDs or {}
    local byName = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local isPetBuff = petBuffIDs[info.itemID] == true
                if isPetBuff or db:IsPetFood(info.itemID, foodTypes) then
                    local name, _, itemLevel = GetItemInfo(info.itemID)
                    if name then
                        if byName[name] then
                            byName[name].count = byName[name].count + (info.stackCount or 1)
                        else
                            byName[name] = {
                                name      = name,
                                itemLevel = itemLevel or 0,
                                count     = info.stackCount or 1,
                                icon      = info.iconFileID,
                                itemID    = info.itemID,
                                isPetBuff = isPetBuff,
                            }
                        end
                    end
                end
            end
        end
    end

    local sorted = {}
    for _, food in pairs(byName) do sorted[#sorted+1] = food end
    -- Pet-buff treats first (direct-use items that buff pet stats), then by item level
    table.sort(sorted, function(a, b)
        local ap = (a.isPetBuff and 0 or 1)
        local bp = (b.isPetBuff and 0 or 1)
        if ap ~= bp then return ap < bp end
        return a.itemLevel > b.itemLevel
    end)

    local result = {}
    for i = 1, math.min(5, #sorted) do result[i] = sorted[i] end
    return result
end

function Pet:CallPet()   CastSpellByName("Call Pet")    end
function Pet:DismissPet() CastSpellByName("Dismiss Pet") end
function Pet:RevivePet() CastSpellByName("Revive Pet")  end
function Pet:MendPet()   CastSpellByName("Mend Pet")    end
