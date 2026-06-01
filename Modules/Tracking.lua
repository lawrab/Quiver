-- Tracks active tracking type and provides quick-switch

local Tracking = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.Tracking = Tracking

-- TBC tracking abilities (shapeshift-style in terms of detection)
local TRACKING_SPELLS = {
    "Track Beasts",
    "Track Humanoids",
    "Track Demons",
    "Track Undead",
    "Track Giants",
    "Track Elementals",
    "Find Herbs",
    "Find Minerals",
    "Find Treasure",
}
Tracking.TRACKING_SPELLS = TRACKING_SPELLS

function Tracking:Initialize()
    self.current = nil
end

function Tracking:Enable()
    Quiver:RegisterEvent("MINIMAP_UPDATE_TRACKING", function() self:UpdateTracking() end)
    Quiver:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:UpdateTracking() end)
    self:UpdateTracking()
end

function Tracking:UpdateTracking()
    -- GetTrackingTexture returns the icon path of the current tracking, or nil
    local texture = GetTrackingTexture()
    self.current = texture
    Quiver.UI.Sphere:UpdateTrackingIndicator()
end

