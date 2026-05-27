-- Tracks ammo (arrows/bullets) count across all bags

local Ammo = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Ammo = Ammo

-- Ammo is stored in the ammo slot (slot 0 in the quiver/ammo bag)
local AMMO_SLOT = 0

function Ammo:Initialize()
    self.count = 0
    self.itemName = nil
    self.wasLow = false
end

function Ammo:Enable()
    Quiver:RegisterEvent("BAG_UPDATE", function() self:UpdateCount() end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:UpdateCount() end)
    self:UpdateCount()
end

function Ammo:UpdateCount()
    -- Ammo in TBC is in the ranged slot bag (slot 0 of quiver)
    -- GetInventoryItemCount works for the equipped ammo pouch
    local ammoSlot = GetInventorySlotInfo("AmmoSlot")
    self.count = GetInventoryItemCount("player", ammoSlot) or 0

    local link = GetInventoryItemLink("player", ammoSlot)
    if link then
        self.itemName = GetItemInfo(link)
    else
        self.itemName = nil
    end

    Quiver.UI.Sphere:UpdateAmmoDisplay()

    -- Only fire once when crossing the threshold downward.
    -- Ignore count == 0: that just means no ammo pouch is equipped.
    local isLow = self.count > 0 and self.count < Quiver.db.profile.ammoWarnThreshold
    if isLow and not self.wasLow then
        self:OnAmmoLow()
    end
    self.wasLow = isLow
end

function Ammo:OnAmmoLow()
    if Quiver.db.profile.sounds.ammoLow then
        -- PlaySoundFile("Interface\\AddOns\\Quiver\\Media\\Sounds\\ammo_low.ogg")
    end
    -- Flash the ammo count red on sphere
    Quiver.UI.Sphere:FlashAmmoWarning()
end

function Ammo:GetCount()
    return self.count
end
