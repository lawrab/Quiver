-- Config panel for sphere click actions.
-- Opens via Alt+Right-click on the sphere.

local Config = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Config = Config

local AceGUI = LibStub("AceGUI-3.0")
local panel = nil

local ACTION_TYPES = { none = "None", spell = "Cast Spell", macro = "Run Macro" }

local function Build()
    local f = AceGUI:Create("Frame")
    f:SetTitle("Quiver Settings")
    f:SetStatusText("Alt+Right-click the sphere to reopen")
    f:SetLayout("List")
    f:SetWidth(400)
    f:SetHeight(260)
    f:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        panel = nil
    end)

    local function AddClickSection(parent, title, dbKey)
        local grp = AceGUI:Create("InlineGroup")
        grp:SetTitle(title)
        grp:SetLayout("Flow")
        grp:SetFullWidth(true)
        parent:AddChild(grp)

        local typeDropdown = AceGUI:Create("Dropdown")
        typeDropdown:SetLabel("Action")
        typeDropdown:SetList(ACTION_TYPES)
        typeDropdown:SetValue(Quiver.db.profile.sphere[dbKey].type)
        typeDropdown:SetWidth(150)
        grp:AddChild(typeDropdown)

        local valueBox = AceGUI:Create("EditBox")
        valueBox:SetLabel("Spell name or macro text")
        valueBox:SetText(Quiver.db.profile.sphere[dbKey].value)
        valueBox:SetWidth(210)
        grp:AddChild(valueBox)

        return typeDropdown, valueBox
    end

    local lcType, lcValue = AddClickSection(f, "Left Click",  "leftClick")
    local rcType, rcValue = AddClickSection(f, "Right Click", "rightClick")

    local apply = AceGUI:Create("Button")
    apply:SetText("Apply")
    apply:SetWidth(100)
    apply:SetCallback("OnClick", function()
        if InCombatLockdown() then
            print("|cffff4444Quiver:|r Cannot change settings during combat.")
            return
        end
        Quiver.db.profile.sphere.leftClick.type   = lcType:GetValue()
        Quiver.db.profile.sphere.leftClick.value  = lcValue:GetText()
        Quiver.db.profile.sphere.rightClick.type  = rcType:GetValue()
        Quiver.db.profile.sphere.rightClick.value = rcValue:GetText()
        Quiver.UI.Sphere:UpdateOnClick()
        AceGUI:Release(f)
        panel = nil
    end)
    f:AddChild(apply)

    return f
end

function Config:Toggle()
    if panel then
        AceGUI:Release(panel)
        panel = nil
        return
    end
    panel = Build()
end
