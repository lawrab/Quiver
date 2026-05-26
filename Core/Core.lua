-- Core initialization, defaults, and event routing

local Core = {}
Quiver.Core = Core

Quiver.defaults = {
    profile = {
        sphere = {
            x = 0,
            y = -200,
            scale = 1.0,
            locked = false,
            leftClick  = "none",
            rightClick = "none",
            leftType   = "spell",
            rightType  = "spell",
            leftMacro  = "",
            rightMacro = "",
        },
        ammoWarnThreshold = 100,
        sounds = {
            ammoLow = true,
            petUnhappy = true,
            killCommand = true,
            bestialWrath = true,
        },
    },
    char = {
        lastAspect = nil,
        lastTracking = nil,
        menuSelections = {},
    },
}

function Core:Initialize()
    -- Migrate leftClick/rightClick from old {type,value} table schema to plain string
    local sp = Quiver.db.profile.sphere
    if type(sp.leftClick) == "table" then sp.leftClick = "none" end
    if type(sp.rightClick) == "table" then sp.rightClick = "none" end

    -- modules init in dependency order
    Quiver.Modules.Ammo:Initialize()
    Quiver.Modules.Mana:Initialize()
    Quiver.Modules.Aspects:Initialize()
    Quiver.Modules.Pet:Initialize()
    Quiver.Modules.Stings:Initialize()
    Quiver.Modules.Traps:Initialize()
    Quiver.Modules.Tracking:Initialize()

    Quiver.UI.Sphere:Initialize()
    Quiver.UI.Menus:Initialize()
end

function Core:Enable()
    Quiver.Modules.Ammo:Enable()
    Quiver.Modules.Mana:Enable()
    Quiver.Modules.Aspects:Enable()
    Quiver.Modules.Pet:Enable()
    Quiver.Modules.Stings:Enable()
    Quiver.Modules.Traps:Enable()
    Quiver.Modules.Tracking:Enable()
end
