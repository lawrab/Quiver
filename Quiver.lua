-- Quiver: Hunter class mod for TBC Anniversary
-- Necrosis-style circular sphere UI for hunter class mechanics

Quiver = LibStub("AceAddon-3.0"):NewAddon("Quiver", "AceEvent-3.0")

function Quiver:OnInitialize()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then
        return
    end

    self.db = LibStub("AceDB-3.0"):New("QuiverDB", self.defaults, true)

    self.Core:Initialize()
end

function Quiver:OnEnable()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end

    self.UI.Sphere:Show()
    self.Core:Enable()
end

function Quiver:OnDisable()
    self.UI.Sphere:Hide()
    self.Core:Disable()
end
