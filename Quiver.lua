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

    SLASH_QUIVER1 = "/quiver"
    SlashCmdList["QUIVER"] = function(msg)
        local cmd = msg:match("^%s*(%S*)") or ""
        if cmd == "reset" then
            Quiver.db.profile.sphere.x = 0
            Quiver.db.profile.sphere.y = -200
            local f = Quiver.UI.Sphere.frame
            if f then
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
            end
            print("|cffffcc00Quiver:|r Sphere position reset.")
        elseif cmd == "config" or cmd == "" then
            Quiver.UI.Config:Toggle()
        else
            print("|cffffcc00Quiver:|r /quiver reset  — move sphere to default position")
            print("|cffffcc00Quiver:|r /quiver config — open settings")
        end
    end
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
