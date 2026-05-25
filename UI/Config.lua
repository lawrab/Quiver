-- Config panel for sphere click actions.
-- Opens via Alt+Right-click on the sphere.

local Config = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Config = Config

local AceGUI = LibStub("AceGUI-3.0")
local panel = nil

-- Ordered list of hunter spells offered as sphere bindings.
-- Filtered to known-only at build time via Menus spell cache.
-- Spells relevant as sphere click bindings (alphabetical).
-- Excludes aspects/traps/tracking/basic pet actions — those have dedicated menus.
local SPHERE_SPELLS = {
    "Aimed Shot",
    "Arcane Shot",
    "Beast Training",
    "Bestial Wrath",
    "Concussive Shot",
    "Counter Attack",
    "Feign Death",
    "Flare",
    "Hunter's Mark",
    "Intimidation",
    "Kill Command",
    "Mend Pet",
    "Misdirection",
    "Multi-Shot",
    "Rapid Fire",
    "Serpent Sting",
    "Steady Shot",
    "Volley",
    "Wing Clip",
    "Wyvern Sting",
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
