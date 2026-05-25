-- Tracks ammo (arrows/bullets) count across all bags

local Ammo = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Ammo = Ammo

-- Ammo is stored in the ammo slot (slot 0 in the quiver/ammo bag)
local AMMO_SLOT = 0

function Ammo:Initialize()
    self.count = 0
    self.itemName = nil
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

    if self.count < Quiver.db.profile.ammoWarnThreshold then
        self:OnAmmoLow()
    end
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
