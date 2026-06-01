-- Minimal WoW API stubs for running logic modules outside the game client.
-- Every function returns a safe default; tests override what they need.

-- ── Core globals ─────────────────────────────────────────────────────────────

math   = math
table  = table
string = string
print  = print
unpack = unpack or table.unpack  -- Lua 5.1 vs 5.2+

-- ── Quiver global skeleton ────────────────────────────────────────────────────

Quiver = {
    Modules = {},
    UI = {
        Sphere = {
            UpdatePetIndicator  = function() end,
            UpdateOnClick       = function() end,
            UpdateAmmoDisplay   = function() end,
            FlashAmmoWarning    = function() end,
            UpdateColor         = function() end,
            UpdateTrackingIndicator = function() end,
        },
        Menus = {
            RebuildFoodPicker   = function() end,
            UpdateTrapCooldowns = function() end,
            ApplySelectionToTrigger = function() end,
            menus = {},
        },
    },
    db = {
        profile = {
            sounds = {
                ammoLow    = false,
                petUnhappy = false,
            },
            notifications = {
                petDied = false,
            },
            ammoWarnThreshold = 100,
        },
        char = {
            menuSelections = {},
        },
    },
}

-- RegisterEvent: store handlers so tests can fire them manually
local _eventHandlers = {}
function Quiver:RegisterEvent(event, handler)
    _eventHandlers[event] = handler
end
function Quiver._fireEvent(event, ...)
    if _eventHandlers[event] then _eventHandlers[event](event, ...) end
end

-- ── Frame stub ────────────────────────────────────────────────────────────────

local FrameMeta = {}
FrameMeta.__index = FrameMeta
function FrameMeta:RegisterEvent() end
function FrameMeta:UnregisterAllEvents() end
function FrameMeta:SetScript(event, fn)
    self._scripts = self._scripts or {}
    self._scripts[event] = fn
end
function FrameMeta:GetScript(event)
    return self._scripts and self._scripts[event]
end
function FrameMeta:Show() end
function FrameMeta:Hide() end
function FrameMeta:SetScript_fire(event, ...)
    local fn = self._scripts and self._scripts[event]
    if fn then fn(self, ...) end
end

function CreateFrame()
    return setmetatable({}, FrameMeta)
end

-- ── Unit API ─────────────────────────────────────────────────────────────────

_G._petExists   = false
_G._petDead     = false
_G._petHappiness = 3

function UnitExists(unit)
    if unit == "pet" then return _G._petExists end
    return false
end

function UnitIsDead(unit)
    if unit == "pet" then return _G._petDead end
    return false
end

function GetPetHappiness()
    return _G._petHappiness
end

-- ── Spell API ─────────────────────────────────────────────────────────────────

_G._spellInfo = {}  -- name → { name, rank, icon }

function GetSpellInfo(spell)
    local info = _G._spellInfo[tostring(spell)]
    if info then return info[1], info[2], info[3] end
    return nil
end

function GetSpellCooldown(spell)
    return _G._spellCooldowns and _G._spellCooldowns[spell] or 0, 0
end

-- ── Time ─────────────────────────────────────────────────────────────────────

_G._time = 0
function GetTime() return _G._time end

-- ── Inventory / ammo ─────────────────────────────────────────────────────────

_G._ammoCount = 0
_G._ammoLink  = nil

function GetInventorySlotInfo(name)
    if name == "AmmoSlot" then return 0 end
    return 0
end

function GetInventoryItemCount(unit, slot)
    return _G._ammoCount
end

function GetInventoryItemLink(unit, slot)
    return _G._ammoLink
end

function GetItemInfo(link)
    return link, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

-- ── Sounds ───────────────────────────────────────────────────────────────────

_G._soundsPlayed = {}
function PlaySound(id)
    table.insert(_G._soundsPlayed, id)
end

-- ── Tracking ─────────────────────────────────────────────────────────────────

_G._trackingTexture = nil
function GetTrackingTexture()
    return _G._trackingTexture
end

-- ── Combat ───────────────────────────────────────────────────────────────────

_G._inCombat = false
function InCombatLockdown() return _G._inCombat end

-- ── Trap cooldowns ───────────────────────────────────────────────────────────

_G._spellCooldowns = {}

-- ── Misc ─────────────────────────────────────────────────────────────────────

function UnitBuff() return nil end
function GetShapeshiftForm() return 0 end
function GetShapeshiftFormInfo() return nil end
function GetPetFoodTypes() return end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
