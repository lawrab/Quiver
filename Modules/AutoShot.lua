-- Auto-shot swing timer: tracks time until next auto shot fires.
-- shotTimer counts DOWN from speed to 0; progress = 1 - shotTimer/speed.

local AutoShot = {}
Quiver.Modules = Quiver.Modules or {}
Quiver.Modules.AutoShot = AutoShot

local AUTO_CAST_WINDOW = 0.5  -- seconds Aimed Shot clips timer to

function AutoShot:Initialize()
    self.speed        = 0
    self.shotTimer    = 0
    self.shooting     = false
    self.casting      = false
    self.moving       = false
    self.inCombat     = false
    self.hasTarget    = false
    self.speedBoosted = false
end

function AutoShot:Enable()
    local f = CreateFrame("Frame")
    f:RegisterEvent("START_AUTOREPEAT_SPELL")
    f:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    f:RegisterEvent("UNIT_ATTACK_SPEED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_FAILED")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("PLAYER_STARTED_MOVING")
    f:RegisterEvent("PLAYER_STOPPED_MOVING")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    -- payload: (event, unit, castGUID, spellID, ...)
    f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
        self:OnEvent(event, unit, spellID)
    end)
    self._eventFrame = f

    self.inCombat  = UnitAffectingCombat("player") and true or false
    self.hasTarget = UnitExists("target") and true or false
    local speed    = UnitRangedDamage("player")
    self.speed     = speed or 0
    self.shotTimer = self.speed
    Quiver.UI.Sphere:UpdateAutoShotBar()
end

function AutoShot:Disable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:SetScript("OnEvent", nil)
        self._eventFrame = nil
    end
    self.shooting = false
    Quiver.UI.Sphere:UpdateAutoShotBar()
end

function AutoShot:OnEvent(event, unit, spellID)
    if event == "START_AUTOREPEAT_SPELL" then
        self.shooting     = true
        self.speedBoosted = false
        local speed       = UnitRangedDamage("player")
        self.speed        = speed or 0
        self.shotTimer    = self.speed
        Quiver.UI.Sphere:UpdateAutoShotBarColor(false)
        Quiver.UI.Sphere:UpdateAutoShotBar()

    elseif event == "STOP_AUTOREPEAT_SPELL" then
        self.shooting = false
        Quiver.UI.Sphere:UpdateAutoShotBar()

    elseif event == "PLAYER_STARTED_MOVING" then
        self.moving    = true
        self.shotTimer = self.speed

    elseif event == "PLAYER_STOPPED_MOVING" then
        self.moving = false

    elseif event == "UNIT_ATTACK_SPEED" then
        if unit ~= "player" then return end
        local newSpeed = UnitRangedDamage("player")
        if newSpeed and newSpeed > 0 and self.speed > 0 then
            self.shotTimer = self.shotTimer * (newSpeed / self.speed)
            local boosted = newSpeed < self.speed * 0.99
            if boosted ~= self.speedBoosted then
                self.speedBoosted = boosted
                Quiver.UI.Sphere:UpdateAutoShotBarColor(boosted)
            end
        end
        self.speed = newSpeed or self.speed

    elseif event == "UNIT_SPELLCAST_START" then
        if unit ~= "player" then return end
        local name = spellID and GetSpellInfo(spellID)
        if name == "Aimed Shot" then
            self.casting   = true
            self.shotTimer = math.min(self.shotTimer, AUTO_CAST_WINDOW)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        local name = spellID and GetSpellInfo(spellID)
        if name == "Auto Shot" then
            self.shotTimer = self.speed
        elseif name == "Aimed Shot" then
            self.casting = false
        end

    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit ~= "player" then return end
        local name = spellID and GetSpellInfo(spellID)
        if name == "Aimed Shot" then
            self.casting = false
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        self.inCombat = true
        Quiver.UI.Sphere:UpdateAutoShotBar()

    elseif event == "PLAYER_REGEN_ENABLED" then
        self.inCombat = false
        self.shooting = false
        Quiver.UI.Sphere:UpdateAutoShotBar()

    elseif event == "PLAYER_TARGET_CHANGED" then
        self.hasTarget = UnitExists("target") and true or false
        Quiver.UI.Sphere:UpdateAutoShotBar()

    elseif event == "PLAYER_ENTERING_WORLD" then
        local speed       = UnitRangedDamage("player")
        self.speed        = speed or 0
        self.shotTimer    = self.speed
        self.moving       = false
        self.speedBoosted = false
        self.inCombat     = UnitAffectingCombat("player") and true or false
        self.hasTarget    = UnitExists("target") and true or false
        Quiver.UI.Sphere:UpdateAutoShotBarColor(false)
        Quiver.UI.Sphere:UpdateAutoShotBar()
    end
end

function AutoShot:Tick(dt)
    if not self.shooting or self.moving then return end
    self.shotTimer = math.max(0, self.shotTimer - dt)
end

function AutoShot:GetProgress()
    if self.speed <= 0 then return 0 end
    return 1 - self.shotTimer / self.speed
end

function AutoShot:ShouldShow()
    return self.inCombat and self.hasTarget and self.shooting
end
