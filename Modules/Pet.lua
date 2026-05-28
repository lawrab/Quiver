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
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:UpdateState() end)
    self:UpdateState()

    -- UNIT_HAPPINESS no longer exists in the Anniversary client; poll every
    -- 5 seconds so the happiness ring stays accurate between pet appearances.
    local elapsed = 0
    self.ticker = CreateFrame("Frame")
    self.ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 5.0 then
            elapsed = 0
            if self.exists then self:UpdateState() end
        end
    end)
end

function Pet:Disable()
    if self.ticker then self.ticker:Hide() end
end

function Pet:UpdateState()
    local wasExists = self.exists
    self.exists = UnitExists("pet")
    if self.exists then
        self.happiness = GetPetHappiness and GetPetHappiness() or nil
    else
        self.happiness = nil
    end
    Quiver.UI.Sphere:UpdatePetIndicator()
    if self.exists ~= wasExists then
        Quiver.UI.Menus:RebuildFoodPicker()
    end

    if self.happiness == 1 and Quiver.db.profile.sounds.petUnhappy then
        -- PlaySoundFile("Interface\\AddOns\\Quiver\\Media\\Sounds\\pet_unhappy.ogg")
    end
end

function Pet:GetHappinessColor()
    if self.happiness then
        return unpack(HAPPINESS_COLORS[self.happiness] or HAPPINESS_COLORS[2])
    end
    return 0.5, 0.5, 0.5
end

local function FoodSortComparator(a, b)
    local ap = (a.isPetBuff and 0 or 1)
    local bp = (b.isPetBuff and 0 or 1)
    if ap ~= bp then return ap < bp end
    if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
    return a.name < b.name
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
            -- Cheap ID-only check first; avoids allocating a GetContainerItemInfo
            -- table for every non-food slot (typically 80–100 per bag scan).
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local isPetBuff = petBuffIDs[itemID] == true
                if isPetBuff or db:IsPetFood(itemID, foodTypes) then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local name, _, _, itemLevel, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
                    if info and name then
                        if byName[name] then
                            byName[name].count = byName[name].count + (info.stackCount or 1)
                        else
                            -- iconFileID from container is always present for bag items;
                            -- itemIcon from GetItemInfo is the fallback if iconFileID is 0
                            local icon = (info.iconFileID and info.iconFileID ~= 0) and info.iconFileID
                                         or (itemIcon and itemIcon ~= 0) and itemIcon
                                         or nil
                            byName[name] = {
                                name      = name,
                                itemLevel = itemLevel or 0,
                                count     = info.stackCount or 1,
                                icon      = icon,
                                itemID    = itemID,
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
    -- Pet-buff treats first (direct-use items that buff pet stats), then by item level desc,
    -- then alphabetically as a stable tiebreaker so order never shuffles.
    table.sort(sorted, FoodSortComparator)

    local result = {}
    for i = 1, math.min(5, #sorted) do result[i] = sorted[i] end
    return result
end

