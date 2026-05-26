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

function Pet:GetSuitableFood()
    if not self.exists then
        Quiver:Print("Quiver Food: no pet active")
        return {}
    end

    local foodTypes = {}
    for _, ft in ipairs({GetPetFoodTypes()}) do
        foodTypes[ft] = true
    end
    Quiver:Print("Quiver Food: pet accepts " .. (next(foodTypes) and table.concat((function() local t={} for k in pairs(foodTypes) do t[#t+1]=k end return t end)(), ", ") or "nothing"))
    if not next(foodTypes) then return {} end

    local byName = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local name, _, itemLevel, _, _, itemType, itemSubType = GetItemInfo(info.itemID)
                if name and itemType == "Consumable" and foodTypes[itemSubType] then
                    if byName[name] then
                        byName[name].count = byName[name].count + (info.stackCount or 1)
                    else
                        byName[name] = { name = name, itemLevel = itemLevel or 0, count = info.stackCount or 1, icon = info.iconFileID, itemID = info.itemID }
                    end
                end
            end
        end
    end

    local sorted = {}
    for _, food in pairs(byName) do sorted[#sorted+1] = food end
    table.sort(sorted, function(a, b) return a.itemLevel > b.itemLevel end)

    local result = {}
    for i = 1, math.min(5, #sorted) do result[i] = sorted[i] end
    Quiver:Print("Quiver Food: found " .. #result .. " food item(s)")
    for i, f in ipairs(result) do
        Quiver:Print("  [" .. i .. "] " .. f.name .. " (ilvl " .. f.itemLevel .. ") x" .. f.count)
    end
    return result
end

function Pet:CallPet()   CastSpellByName("Call Pet")    end
function Pet:DismissPet() CastSpellByName("Dismiss Pet") end
function Pet:RevivePet() CastSpellByName("Revive Pet")  end
function Pet:MendPet()   CastSpellByName("Mend Pet")    end
