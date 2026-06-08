std = "lua51"
max_line_length = false

-- Suppress "unused argument 'self'" globally — very common in Lua module methods
-- that access state via the module reference rather than through self.
ignore = {"212/self"}

-- Addon globals defined across files (not all in one place)
globals = {
    "Quiver",
    -- Slash command registration — WoW globals that must be written to
    "SLASH_QUIVER1",
    "SlashCmdList",
}

-- WoW API globals — read-only from luacheck's perspective
read_globals = {
    -- Core WoW
    "UIParent",
    "GameTooltip",
    "UIErrorsFrame",
    "BOOKTYPE_SPELL",

    -- Frame creation
    "CreateFrame",

    -- Spell API
    "GetSpellInfo",
    "GetSpellCooldown",
    "GetShapeshiftForm",
    "GetShapeshiftFormInfo",
    "IsSpellKnown",

    -- Unit API
    "UnitExists",
    "UnitIsDead",
    "UnitBuff",
    "UnitDebuff",
    "UnitClass",
    "UnitAffectingCombat",
    "UnitName",
    "UnitPower",
    "UnitPowerMax",
    "UnitRangedDamage",

    -- Pet API
    "GetPetHappiness",
    "GetPetFoodTypes",

    -- Inventory / bag API
    "GetInventorySlotInfo",
    "GetInventoryItemCount",
    "GetInventoryItemLink",
    "GetItemInfo",
    "C_Container",

    -- Tracking
    "GetTrackingTexture",

    -- Combat / state
    "InCombatLockdown",
    "GetTime",
    "GetCVarBool",
    "IsAltKeyDown",

    -- Slash commands
    "SLASH_QUIVER1",

    -- Ace3 / LibStub
    "LibStub",

    -- Sound
    "PlaySound",
    "PlaySoundFile",
    "SOUNDKIT",

    -- Spell book
    "GetNumSpellTabs",
    "GetSpellTabInfo",
    "GetSpellBookItemInfo",
    "GetSpellBookItemName",

    -- UI templates / globals
    "UIPanelButtonTemplate",
    "UICheckButtonTemplate",

    -- Keybind / CVar
    "GetCVar",
    "SetCVar",
    "GetBindingKey",

    -- Macro API
    "GetMacroIndexByName",
    "GetNumMacros",
    "CreateMacro",
    "EditMacro",
    "DeleteMacro",

    -- Misc
    "math",
    "table",
    "string",
    "print",
    "unpack",
    "pairs",
    "ipairs",
    "next",
    "type",
    "tostring",
    "tonumber",
    "select",
    "wipe",
}

-- Don't lint the vendored Ace3 libraries
exclude_files = { "Libs/**" }

-- Test files write the WoW API globals that production code only reads.
-- Promote them to writable for the tests directory.
files["tests/"] = {
    globals = {
        "math", "table", "string", "print", "unpack",
        "CreateFrame",
        "UnitExists", "UnitIsDead", "UnitBuff",
        "GetPetHappiness", "GetPetFoodTypes",
        "GetSpellInfo", "GetSpellCooldown",
        "GetShapeshiftForm", "GetShapeshiftFormInfo",
        "GetTime",
        "GetInventorySlotInfo", "GetInventoryItemCount", "GetInventoryItemLink",
        "GetItemInfo",
        "PlaySound",
        "GetTrackingTexture",
        "InCombatLockdown",
        "wipe",
    }
}
