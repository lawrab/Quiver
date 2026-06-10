-- Help window: multi-page reference opened from the Settings "?" button.

local Help = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Help = Help

local helpWin   = nil
local pageIndex = 1

-- ── Page content ──────────────────────────────────────────────────────────────

local H = "|cffffcc00"   -- gold header
local W = "|cffffffff"   -- white key term
local C = "|cff4dd9ff"   -- cyan tip
local E = "|r"           -- end colour

local PAGES = {
    {
        title = "Getting Started",
        text  = H.."The Sphere"..E.."\n"..
"Quiver's central orb sits on screen and is your one-stop hub for every hunter mechanic. "..
"Drag it anywhere — it snaps to wherever you drop it and remembers the position across sessions.\n\n"..
H.."Opening Settings"..E.."\n"..
W.."Alt + Right-click"..E.." the sphere to open the Settings panel. From there you can bind left and right clicks to spells or macros, toggle sound alerts, and generate action bar macros.\n\n"..
H.."The Seven Orbit Buttons"..E.."\n"..
"Seven small buttons orbit the sphere, one for each hunter system:\n\n"..
W.."  Tank Mode"..E.."  — Growl autocast toggle + BW macro control\n"..
W.."  Pet"..E.."        — Call, Dismiss, Revive, Mend Pet\n"..
W.."  Aspects"..E.."    — Instant aspect switching\n"..
W.."  Tracking"..E.."   — Switch tracking type\n"..
W.."  Traps"..E.."      — Frost, Freezing, Immolation, Explosive, Snake\n"..
W.."  Stings"..E.."     — Serpent, Viper, Scorpid, Wyvern Sting\n"..
W.."  Food"..E.."       — Feed your pet from your bags\n\n"..
C.."Tip: right-click any orbit button to close open menus."..E,
    },

    {
        title = "Pet & Tank Mode",
        text  = H.."Pet Status Ring"..E.."\n"..
"A coloured ring around the sphere shows your pet's happiness at a glance: "..
W.."green"..E.." = happy, "..W.."yellow"..E.." = content, "..W.."red"..E.." = unhappy. "..
"Unhappy pets deal noticeably less damage — keep them fed. "..
"If your pet dies, a chat message reminds you to right-click the sphere to revive.\n\n"..
H.."Pet Orbit Menu"..E.."\n"..
"Left-click the "..W.."Pet"..E.." orbit button to open the pet menu: "..
"Call Pet, Dismiss, Revive, and Mend Pet. "..
"The correct button is shown automatically depending on whether your pet is alive, dead, or absent.\n\n"..
H.."Feeding Your Pet"..E.."\n"..
"Left-click the "..W.."Food"..E.." orbit button to open the food picker. "..
"Quiver scans your bags, filters to foods your current pet can eat, and shows up to 5 options sorted by item level. "..
"Pet-buff treats (like Kibler's Bits) appear at the top. Your selection is saved per character.\n\n"..
H.."Tank Mode"..E.."\n"..
"Left-click the "..W.."Tank Mode"..E.." orbit button (the taunt/Growl icon) to toggle pet tanking on or off.\n\n"..
W.."ON"..E..": Growl autocast enabled — pet holds aggro. The "..W.."Quiver: BW"..E.." macro includes Intimidation for an extra threat burst.\n"..
W.."OFF"..E..": Growl autocast disabled — pet deals damage without taunting, safe for raids and parties.\n\n"..
C.."Note: the pet bar is hidden while mounted, so the button is disabled on mount. "..
"Your saved preference is restored when you dismount."..E,
    },

    {
        title = "Aspects & Tracking",
        text  = H.."Quick Aspect Switching"..E.."\n"..
"Left-click the "..W.."Aspects"..E.." orbit button to open the aspect menu. "..
"Click any aspect to cast it immediately — the sphere changes colour to reflect the active aspect:\n\n"..
W.."  Green"..E.."  — Aspect of the Hawk (main DPS)\n"..
W.."  Blue"..E.."   — Aspect of the Viper (mana regen)\n"..
W.."  Yellow"..E.." — Aspect of the Cheetah / Pack (speed)\n"..
W.."  Purple"..E.." — Aspect of the Dragonhawk (Hawk + Monkey)\n"..
W.."  Teal"..E.."   — Aspect of the Wild (nature resistance)\n"..
W.."  Orange"..E.." — Aspect of the Monkey (dodge)\n\n"..
H.."Quick-swap Badge"..E.."\n"..
"Once you have used two different aspects, a small badge icon appears in the corner of the Aspects button showing your "..W.."previous"..E.." aspect. "..
"Left-clicking the sphere directly (if bound to Aspects) swaps between your last two aspects instantly — handy for toggling Hawk and Viper mid-fight.\n\n"..
H.."Tracking"..E.."\n"..
"Left-click the "..W.."Tracking"..E.." orbit button to open the tracking menu. "..
"Available tracking types depend on your talents and race. "..
"A small indicator on the sphere shows the current tracking type is active.",
    },

    {
        title = "Stings & Traps",
        text  = H.."Stings"..E.."\n"..
"Stings are mutually exclusive on a target — applying a new sting overwrites the previous one. "..
"Left-click the "..W.."Stings"..E.." orbit button to see your sting options:\n\n"..
W.."  Serpent Sting"..E.."  — Nature DoT, your main PvE sting. Refresh before it falls off.\n"..
W.."  Viper Sting"..E.."    — Drains mana; useful against casters and in PvP.\n"..
W.."  Scorpid Sting"..E.."  — Reduces target's chance to hit; strong in PvP.\n"..
W.."  Wyvern Sting"..E.."   — Sleep + DoT (Survival talent); breaks on damage.\n\n"..
"Selecting a sting also writes the "..W.."Quiver: Sting"..E.." macro in your macro book with the correct spell — drag it to your bars for easy use.\n\n"..
H.."Traps"..E.."\n"..
"Left-click the "..W.."Traps"..E.." orbit button to open the trap menu. "..
"In TBC, traps can be placed in combat. Available traps:\n\n"..
W.."  Frost Trap"..E.."       — AoE slow field on the ground\n"..
W.."  Freezing Trap"..E.."    — Single-target CC; breaks on damage\n"..
W.."  Immolation Trap"..E.." — Fire damage on trigger\n"..
W.."  Explosive Trap"..E.."   — AoE fire damage\n"..
W.."  Snake Trap"..E.."       — Summons venomous snakes\n\n"..
C.."Tip: trap cooldowns are shared — casting one trap starts the cooldown on all."..E,
    },

    {
        title = "Macro Generator",
        text  = H.."What It Does"..E.."\n"..
"The Macro Generator (Settings → Macros tab) creates four macros in your macro book. "..
"Drag them to your action bars — Quiver keeps them up to date automatically.\n\n"..
H.."Quiver: Open"..E.."\n"..
"Your pull macro. On cast it orders your pet to follow, sends it to attack, then fires your chosen opening shot. "..
"Choose the shot in Settings (Aimed, Arcane, Auto Shot, Concussive Shot, Hunter's Mark, Multi-Shot, or Steady Shot). "..
"The "..W.."[known:]"..E.." conditional means the macro works even if you have not trained that rank yet.\n\n"..
H.."Quiver: BW"..E.."\n"..
"Bestial Wrath burst macro. In "..W.."Tank Mode ON"..E.." it also casts Intimidation for extra pet threat. "..
"In "..W.."Tank Mode OFF"..E.." Intimidation is omitted — safe for raids where surprise threat spikes wipe groups.\n\n"..
H.."Quiver: MD"..E.."\n"..
"Misdirection cast on your "..W.."focus"..E..". Set your tank as focus once per fight and spam this freely.\n\n"..
H.."Quiver: Sting"..E.."\n"..
"Updated automatically when you pick a sting from the Stings menu. "..
"Always casts whichever sting you last selected.\n\n"..
C.."Tip: click Create / Update any time you change settings — macros are not updated live."..E,
    },

    {
        title = "Alerts & Tips",
        text  = H.."Sound Alerts"..E.."\n"..
"Toggle alerts in Settings → Macros tab:\n\n"..
W.."  Ammo low"..E.."       — fires when your arrow or bullet count drops below the threshold (default 100)\n"..
W.."  Pet unhappy"..E.."    — fires when your pet transitions into the unhappy state\n\n"..
H.."Ammo Counter"..E.."\n"..
"Quiver scans your bags on every "..W.."BAG_UPDATE"..E.." event and shows the total ammo count. "..
"The count turns "..W.."red"..E.." when below the warning threshold. Stock up before long boss pulls.\n\n"..
H.."Sphere Click Bindings"..E.."\n"..
"You can bind the sphere's left and right clicks to any known spell or a custom macro line. "..
"Popular choices: "..W.."Hunter's Mark"..E.." on left-click, "..W.."Feign Death"..E.." on right-click. "..
"Configure in Settings → Bindings tab.\n\n"..
H.."General Tips"..E.."\n"..
C.."  • Keep Aspect of the Hawk active in combat. Switch to Viper when below ~20% mana and swap back once recovered.\n"..
"  • Set your main tank as focus at the start of every fight for reliable MD targeting.\n"..
"  • Turn Tank Mode OFF in raids and parties unless your pet is intentionally tanking — Growl causes unexpected threat.\n"..
"  • Auto Shot as your opener starts the ranged auto-attack cycle without a GCD, great for long pull distances.\n"..
"  • Freezing Trap breaks on any damage — drop it, then use non-DoT shots on other targets."..E,
    },
}

-- ── Window builder ─────────────────────────────────────────────────────────────

local WIN_W     = 440
local WIN_H     = 480
local PADDING   = 16
local TITLE_H   = 40
local NAV_H     = 36
local CONTENT_W = WIN_W - PADDING * 2

local function Build()
    local f = CreateFrame("Frame", "QuiverHelpWindow", UIParent, "BackdropTemplate")
    f:SetWidth(WIN_W)
    f:SetHeight(WIN_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local titleStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleStr:SetPoint("TOP", f, "TOP", 0, -14)
    f._helpTitle = titleStr

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Scrollable text area
    local scrollBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT",     f, "TOPLEFT",     PADDING,  -TITLE_H)
    scrollBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING,  NAV_H + PADDING)
    scrollBg:SetBackdrop({
        bgFile  = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.55)
    scrollBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    local sf = CreateFrame("ScrollFrame", nil, scrollBg)
    sf:SetPoint("TOPLEFT",     scrollBg, "TOPLEFT",     6,  -6)
    sf:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -6,  6)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 30)))
    end)

    local contentFrame = CreateFrame("Frame", nil, sf)
    contentFrame:SetWidth(CONTENT_W - 12)
    contentFrame:SetHeight(2000)
    sf:SetScrollChild(contentFrame)

    local display = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    display:SetWidth(CONTENT_W - 12)
    display:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    display:SetJustifyH("LEFT")
    display:SetJustifyV("TOP")
    display:SetSpacing(4)
    f._helpDisplay = display
    f._helpSF      = sf

    -- Nav bar: prev / counter / next
    local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prevBtn:SetSize(80, 24)
    prevBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PADDING, PADDING)
    prevBtn:SetText("< Prev")

    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(80, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    nextBtn:SetText("Next >")

    local counterStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    counterStr:SetPoint("BOTTOM", f, "BOTTOM", 0, PADDING + 4)
    counterStr:SetTextColor(0.7, 0.7, 0.7)
    f._helpCounter = counterStr

    local function ShowPage(n)
        pageIndex = math.max(1, math.min(#PAGES, n))
        local page = PAGES[pageIndex]
        f._helpTitle:SetText("Quiver Help  —  " .. page.title)
        f._helpDisplay:SetText(page.text)
        f._helpCounter:SetText(pageIndex .. " / " .. #PAGES)
        f._helpSF:SetVerticalScroll(0)
        prevBtn:SetEnabled(pageIndex > 1)
        nextBtn:SetEnabled(pageIndex < #PAGES)
    end

    prevBtn:SetScript("OnClick", function() ShowPage(pageIndex - 1) end)
    nextBtn:SetScript("OnClick", function() ShowPage(pageIndex + 1) end)

    f._showPage = ShowPage
    f:Hide()
    return f
end

-- ── Public API ─────────────────────────────────────────────────────────────────

local function PositionWindow()
    local cfg = _G["QuiverConfigPanel"]
    helpWin:ClearAllPoints()
    if cfg and cfg:IsShown() then
        helpWin:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 10, 0)
    else
        helpWin:SetPoint("CENTER", UIParent, "CENTER")
    end
end

function Help:Toggle()
    if not helpWin then helpWin = Build() end
    if helpWin:IsShown() then
        helpWin:Hide()
    else
        PositionWindow()
        helpWin._showPage(pageIndex)
        helpWin:Show()
    end
end

function Help:Open(n)
    if not helpWin then helpWin = Build() end
    PositionWindow()
    helpWin._showPage(n or 1)
    helpWin:Show()
end
