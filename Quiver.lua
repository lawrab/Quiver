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
end

SLASH_QUIVERDEBUG1 = "/quiverdebug"
SlashCmdList["QUIVERDEBUG"] = function()
    print("|cff00ff00Quiver Debug|r")

    local numForms = GetNumShapeshiftForms()
    print("GetShapeshiftForm() = " .. tostring(GetShapeshiftForm()))
    print("GetNumShapeshiftForms() = " .. tostring(numForms))
    for i = 1, numForms do
        local icon, active, castable, spellID = GetShapeshiftFormInfo(i)
        local name = spellID and GetSpellInfo(spellID) or "?"
        print(string.format("  Form %d: active=%s spellID=%s name=%s", i, tostring(active), tostring(spellID), tostring(name)))
    end

    print("Player buffs (UnitBuff):")
    local i = 1
    while true do
        local name, _, icon = UnitBuff("player", i)
        if not name then break end
        print(string.format("  Buff %d: %s", i, tostring(name)))
        i = i + 1
        if i > 40 then print("  (truncated)") break end
    end

    local cur = Quiver.Modules.Aspects.current
    print("Aspects.current = " .. (cur and cur.name or "nil"))
    print("Sphere.pulsingAspect = " .. tostring(Quiver.UI.Sphere.pulsingAspect))
end
