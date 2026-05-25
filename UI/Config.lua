-- Config panel for sphere click actions.
-- Opens via Alt+Right-click on the sphere.

local Config = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Config = Config

local AceGUI = LibStub("AceGUI-3.0")
local panel = nil

-- Ordered list of hunter spells offered as sphere bindings.
-- Filtered to known-only at build time via Menus spell cache.
local SPHERE_SPELLS = {
    "Hunter's Mark",
    "Feign Death",
    "Misdirection",
    "Rapid Fire",
    "Bestial Wrath",
    "Kill Command",
    "Intimidation",
    "Flare",
    "Multi-Shot",
    "Aimed Shot",
    "Steady Shot",
    "Arcane Shot",
    "Volley",
    "Wing Clip",
    "Concussive Shot",
    "Counter Attack",
    "Aspect of the Hawk",
    "Aspect of the Viper",
    "Aspect of the Cheetah",
    "Aspect of the Pack",
    "Aspect of the Wild",
    "Aspect of the Monkey",
    "Aspect of the Dragonhawk",
    "Serpent Sting",
    "Viper Sting",
    "Scorpid Sting",
    "Wyvern Sting",
    "Frost Trap",
    "Freezing Trap",
    "Immolation Trap",
    "Explosive Trap",
    "Snake Trap",
    "Call Pet",
    "Dismiss Pet",
    "Revive Pet",
    "Mend Pet",
    "Beast Training",
}

local function BuildSpellList()
    local cache = Quiver.UI.Menus:GetKnownSpells()
    local items = { none = "None" }
    local order = { "none" }
    for _, spell in ipairs(SPHERE_SPELLS) do
        if cache[spell] then
            items[spell] = spell
            table.insert(order, spell)
        end
    end
    return items, order
end

local function Build()
    local items, order = BuildSpellList()

    local f = AceGUI:Create("Frame")
    f:SetTitle("Quiver Settings")
    f:SetStatusText("Alt+Right-click sphere to reopen")
    f:SetLayout("List")
    f:SetWidth(300)
    f:SetHeight(190)
    f:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        panel = nil
    end)

    local lcDrop = AceGUI:Create("Dropdown")
    lcDrop:SetLabel("Left Click")
    lcDrop:SetList(items, order)
    lcDrop:SetValue(Quiver.db.profile.sphere.leftClick)
    lcDrop:SetFullWidth(true)
    f:AddChild(lcDrop)

    local rcDrop = AceGUI:Create("Dropdown")
    rcDrop:SetLabel("Right Click")
    rcDrop:SetList(items, order)
    rcDrop:SetValue(Quiver.db.profile.sphere.rightClick)
    rcDrop:SetFullWidth(true)
    f:AddChild(rcDrop)

    local apply = AceGUI:Create("Button")
    apply:SetText("Apply")
    apply:SetWidth(100)
    apply:SetCallback("OnClick", function()
        if InCombatLockdown() then
            print("|cffff4444Quiver:|r Cannot change settings during combat.")
            return
        end
        Quiver.db.profile.sphere.leftClick  = lcDrop:GetValue()
        Quiver.db.profile.sphere.rightClick = rcDrop:GetValue()
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
