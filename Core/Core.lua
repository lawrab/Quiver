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
    },
}

function Core:Initialize()
    -- modules init in dependency order
    Quiver.Modules.Ammo:Initialize()
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
    Quiver.Modules.Aspects:Enable()
    Quiver.Modules.Pet:Enable()
    Quiver.Modules.Stings:Enable()
    Quiver.Modules.Traps:Enable()
    Quiver.Modules.Tracking:Enable()
end
