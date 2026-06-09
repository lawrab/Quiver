-- Config panel: sphere click bindings, alerts, and macro generator.
-- Opens via Alt+Right-click on the sphere.

local Config = {}
Quiver.UI = Quiver.UI or {}
Quiver.UI.Config = Config

-- Panel is built once and reused; nil until first open.
local panel = nil

local ITEM_H    = 20
local ROWS      = 6
local COL_W     = 240
local PADDING   = 20
local HDR_H     = 16
local TABS_H    = 26
local CONTENT_H = ROWS * ITEM_H
local SECTION_H = HDR_H + TABS_H + CONTENT_H   -- 162
local GAP       = 12
local PANEL_W   = COL_W + PADDING * 2

-- Tab bar: 24px buttons + 4px gap before page content
local TAB_BAR_H = 28

-- Per-page content heights
local BIND_PAGE_H   = SECTION_H + GAP + SECTION_H                    -- 336
local MACRO_H       = 20 + (18+22+6) + (18+6) + (18+6) + 28   -- 142
local MACROS_PAGE_H = (24+4+24+4+24) + GAP + MACRO_H          -- 234

local PAGE_H   = math.max(BIND_PAGE_H, MACROS_PAGE_H)   -- 336
local PAGE_Y   = -(40 + TAB_BAR_H)                       -- where page content starts
local PANEL_H  = 40 + TAB_BAR_H + PAGE_H + 46            -- 450

local SHOTS = { "Aimed Shot", "Arcane Shot", "Concussive Shot", "Hunter's Mark", "Multi-Shot", "Steady Shot" }

local function MakeCycleControl(parent, keyLabel, options, initValue)
    local ARROW_W = 22
    local KEY_W   = 52
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(COL_W)
    f:SetHeight(22)

    local idx = 1
    for i, v in ipairs(options) do
        if v == initValue then idx = i; break end
    end

    local keyLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keyLbl:SetWidth(KEY_W)
    keyLbl:SetPoint("LEFT", f, "LEFT", 0, 0)
    keyLbl:SetJustifyH("LEFT")
    keyLbl:SetText(keyLabel)
    keyLbl:SetTextColor(0.7, 0.7, 0.7)

    local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prevBtn:SetSize(ARROW_W, ARROW_W)
    prevBtn:SetPoint("LEFT", keyLbl, "RIGHT", 4, 0)
    prevBtn:SetText("<")

    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(ARROW_W, ARROW_W)
    nextBtn:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    nextBtn:SetText(">")

    local valLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLbl:SetPoint("LEFT",  prevBtn, "RIGHT", 4, 0)
    valLbl:SetPoint("RIGHT", nextBtn, "LEFT",  -4, 0)
    valLbl:SetJustifyH("CENTER")
    valLbl:SetText(options[idx])
    valLbl:SetTextColor(1, 0.82, 0)

    prevBtn:SetScript("OnClick", function()
        idx = ((idx - 2) % #options) + 1
        valLbl:SetText(options[idx])
    end)
    nextBtn:SetScript("OnClick", function()
        idx = (idx % #options) + 1
        valLbl:SetText(options[idx])
    end)

    f.GetValue = function() return options[idx] end
    f.SetValue = function(val)
        for i, v in ipairs(options) do
            if v == val then idx = i; valLbl:SetText(v); return end
        end
    end
    return f
end

local function GetSpellEntries()
    local entries = {{ id = "none", label = "None" }}
    local cache = Quiver.UI.Menus:GetKnownSpells()
    local names = {}
    for name in pairs(cache) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        entries[#entries + 1] = { id = name, label = name }
    end
    return entries
end

-- Creates a binding section frame.  Call :Refresh(entries, initType, initSpell, initMacro)
-- each time the panel opens to sync content without recreating frames.
local function MakeBindingSection(parent, labelText)
    local currentType   = "spell"
    local selectedSpell = "none"
    local allBtns       = {}

    local container = CreateFrame("Frame", nil, parent)
    container:SetWidth(COL_W)
    container:SetHeight(SECTION_H)

    local hdr = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT")
    hdr:SetText(labelText)
    hdr:SetTextColor(1, 0.82, 0)

    local TAB_W   = math.floor(COL_W / 3) - 2
    local tabDefs = { "spell", "macro", "none" }
    local tabBtns = {}

    local spellFrame, macroFrame, noneFrame, macroEB

    local function SetActiveTab(t)
        currentType = t
        for _, tb in ipairs(tabBtns) do
            local active = (tb.tabType == t)
            tb:GetFontString():SetTextColor(active and 1 or 0.5, active and 0.82 or 0.5, active and 0 or 0.5)
        end
        spellFrame:SetShown(t == "spell")
        macroFrame:SetShown(t == "macro")
        noneFrame:SetShown(t  == "none")
    end

    for i, tabId in ipairs(tabDefs) do
        local tb = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        tb.tabType = tabId
        tb:SetWidth(TAB_W)
        tb:SetHeight(22)
        tb:SetText(tabId:sub(1,1):upper() .. tabId:sub(2))
        tb:SetPoint("TOPLEFT", (i - 1) * (TAB_W + 3), -HDR_H - 4)
        local captured = tabId
        tb:SetScript("OnClick", function() SetActiveTab(captured) end)
        tabBtns[i] = tb
    end

    local CONTENT_Y = -(HDR_H + TABS_H)

    spellFrame = CreateFrame("Frame", nil, container)
    spellFrame:SetWidth(COL_W)
    spellFrame:SetHeight(CONTENT_H)
    spellFrame:SetPoint("TOPLEFT", 0, CONTENT_Y)

    local listBg = spellFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    listBg:SetVertexColor(0, 0, 0, 0.55)

    local sf = CreateFrame("ScrollFrame", nil, spellFrame)
    sf:SetAllPoints()
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ITEM_H * 3)))
    end)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(COL_W)
    content:SetHeight(ITEM_H)
    sf:SetScrollChild(content)

    local function RefreshHL()
        for _, b in ipairs(allBtns) do
            local isSel = (b.spellId == selectedSpell)
            if isSel then
                b.selTex:Show()
                b.accent:Show()
                b.txt:SetTextColor(1, 0.82, 0)
            else
                b.selTex:Hide()
                b.accent:Hide()
                b.txt:SetTextColor(0.62, 0.62, 0.62)
            end
        end
    end

    local function MakeListButton(i)
        local b = CreateFrame("Button", nil, content)
        b:SetWidth(COL_W)
        b:SetHeight(ITEM_H)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_H)
        b.spellId = "none"

        local selTex = b:CreateTexture(nil, "BACKGROUND")
        selTex:SetAllPoints()
        selTex:SetTexture(0.18, 0.48, 0.86, 0.65)
        selTex:Hide()
        b.selTex = selTex

        local accent = b:CreateTexture(nil, "ARTWORK")
        accent:SetWidth(3)
        accent:SetPoint("TOPLEFT",    b, "TOPLEFT",    0, 0)
        accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        accent:SetTexture(1, 0.82, 0, 1)
        accent:Hide()
        b.accent = accent

        b:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameBackground")
        b:GetHighlightTexture():SetVertexColor(0.9, 0.9, 0.9, 0.12)

        local txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.txt = txt

        b:SetScript("OnEnter", function()
            if b.spellId ~= selectedSpell then b.txt:SetTextColor(1, 1, 1) end
        end)
        b:SetScript("OnLeave", function()
            if b.spellId ~= selectedSpell then b.txt:SetTextColor(0.62, 0.62, 0.62) end
        end)
        b:SetScript("OnClick", function()
            selectedSpell = b.spellId
            RefreshHL()
        end)
        return b
    end

    macroFrame = CreateFrame("Frame", nil, container)
    macroFrame:SetWidth(COL_W)
    macroFrame:SetHeight(CONTENT_H)
    macroFrame:SetPoint("TOPLEFT", 0, CONTENT_Y)

    local macroBg = macroFrame:CreateTexture(nil, "BACKGROUND")
    macroBg:SetAllPoints()
    macroBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    macroBg:SetVertexColor(0, 0, 0, 0.55)

    local macroHint = macroFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    macroHint:SetPoint("BOTTOMLEFT", macroFrame, "BOTTOMLEFT", 6, 4)
    macroHint:SetText("One command per line  |  /cast, /use, /target, etc.")

    local macroSF = CreateFrame("ScrollFrame", nil, macroFrame)
    macroSF:SetPoint("TOPLEFT",     macroFrame, "TOPLEFT",     2, -2)
    macroSF:SetPoint("BOTTOMRIGHT", macroFrame, "BOTTOMRIGHT", -2, 18)
    macroSF:EnableMouseWheel(true)
    macroSF:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 14)))
    end)

    macroEB = CreateFrame("EditBox", nil, macroSF)
    macroEB:SetWidth(COL_W - 8)
    macroEB:SetHeight(CONTENT_H * 4)
    macroEB:SetMultiLine(true)
    macroEB:SetAutoFocus(false)
    macroEB:SetFontObject("GameFontNormalSmall")
    macroEB:SetTextInsets(6, 6, 4, 4)
    macroEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    macroSF:SetScrollChild(macroEB)

    noneFrame = CreateFrame("Frame", nil, container)
    noneFrame:SetWidth(COL_W)
    noneFrame:SetHeight(CONTENT_H)
    noneFrame:SetPoint("TOPLEFT", 0, CONTENT_Y)

    local noneBg = noneFrame:CreateTexture(nil, "BACKGROUND")
    noneBg:SetAllPoints()
    noneBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    noneBg:SetVertexColor(0, 0, 0, 0.3)

    local noneLbl = noneFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noneLbl:SetPoint("CENTER")
    noneLbl:SetText("No action assigned")

    function container:Refresh(entries, initType, initSpell, initMacro)
        currentType   = initType  or "spell"
        selectedSpell = initSpell or "none"
        macroEB:SetText(initMacro or "")

        for i = #allBtns + 1, #entries do
            allBtns[i] = MakeListButton(i)
        end

        content:SetHeight(#entries * ITEM_H)
        for i, entry in ipairs(entries) do
            local b = allBtns[i]
            b.spellId = entry.id
            b.txt:SetText(entry.label)
            b:Show()
        end
        for i = #entries + 1, #allBtns do
            allBtns[i]:Hide()
        end

        RefreshHL()

        for i, entry in ipairs(entries) do
            if entry.id == selectedSpell then
                local y = math.max(0, (i - 1) * ITEM_H - math.floor(ROWS / 2) * ITEM_H)
                sf:SetVerticalScroll(y)
                break
            end
        end

        SetActiveTab(currentType)
    end

    container.GetType  = function() return currentType end
    container.GetSpell = function() return selectedSpell end
    container.GetMacro = function() return macroEB:GetText() end
    return container
end

local function Build()
    local f = CreateFrame("Frame", "QuiverConfigPanel", UIParent, "BackdropTemplate")
    f:SetWidth(PANEL_W)
    f:SetHeight(PANEL_H)
    f:SetPoint("CENTER")
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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText("Quiver Settings")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    hint:SetText("Alt+Right-click sphere to reopen")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Page tab buttons ───────────────────────────────────────────────────────
    local TAB_W   = math.floor(COL_W / 2) - 2
    local tabBtns = {}
    local pages   = {}

    -- Defined after pages/buttons are created; stored on f so Toggle can call it.
    local ShowPage
    f.ShowPage = function(name) if ShowPage then ShowPage(name) end end

    local tabDefs = { { id = "bindings", label = "Bindings" }, { id = "macros", label = "Macros" } }
    for i, def in ipairs(tabDefs) do
        local tb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tb.pageName = def.id
        tb:SetWidth(TAB_W)
        tb:SetHeight(24)
        tb:SetText(def.label)
        tb:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING + (i - 1) * (TAB_W + 4), -40)
        local captured = def.id
        tb:SetScript("OnClick", function() f.ShowPage(captured) end)
        tabBtns[i] = tb
    end

    -- ── Bindings page ──────────────────────────────────────────────────────────
    local bindingsPage = CreateFrame("Frame", nil, f)
    bindingsPage:SetWidth(COL_W)
    bindingsPage:SetHeight(BIND_PAGE_H)
    bindingsPage:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, PAGE_Y)
    pages.bindings = bindingsPage

    local lcSection = MakeBindingSection(bindingsPage, "Left Click")
    lcSection:SetPoint("TOPLEFT", bindingsPage, "TOPLEFT", 0, 0)
    f.lcSection = lcSection

    local rcSection = MakeBindingSection(bindingsPage, "Right Click")
    rcSection:SetPoint("TOPLEFT", lcSection, "BOTTOMLEFT", 0, -GAP)
    f.rcSection = rcSection

    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetWidth(80)
    applyBtn:SetHeight(22)
    applyBtn:SetText("Apply")
    applyBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)
    applyBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            print("|cffff4444Quiver:|r Cannot change settings during combat.")
            return
        end
        local sp      = Quiver.db.profile.sphere
        sp.leftType   = lcSection.GetType()
        sp.leftClick  = lcSection.GetSpell()
        sp.leftMacro  = lcSection.GetMacro()
        sp.rightType  = rcSection.GetType()
        sp.rightClick = rcSection.GetSpell()
        sp.rightMacro = rcSection.GetMacro()
        Quiver.UI.Sphere:UpdateOnClick()
        f:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetWidth(80)
    cancelBtn:SetHeight(22)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetPoint("RIGHT", applyBtn, "LEFT", -4, 0)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Macros page ────────────────────────────────────────────────────────────
    local macrosPage = CreateFrame("Frame", nil, f)
    macrosPage:SetWidth(COL_W)
    macrosPage:SetHeight(MACROS_PAGE_H)
    macrosPage:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, PAGE_Y)
    pages.macros = macrosPage

    local notifyCheck = CreateFrame("CheckButton", nil, macrosPage, "UICheckButtonTemplate")
    notifyCheck:SetSize(24, 24)
    notifyCheck:SetPoint("TOPLEFT", macrosPage, "TOPLEFT", -2, 0)
    notifyCheck.text:SetText("Notify in chat when pet dies")
    notifyCheck:SetScript("OnClick", function(self)
        Quiver.db.profile.notifications.petDied = self:GetChecked()
    end)
    f.notifyCheck = notifyCheck

    local soundAmmoCheck = CreateFrame("CheckButton", nil, macrosPage, "UICheckButtonTemplate")
    soundAmmoCheck:SetSize(24, 24)
    soundAmmoCheck:SetPoint("TOPLEFT", notifyCheck, "BOTTOMLEFT", 0, -4)
    soundAmmoCheck.text:SetText("Sound alert when ammo is low")
    soundAmmoCheck:SetScript("OnClick", function(self)
        Quiver.db.profile.sounds.ammoLow = self:GetChecked()
    end)
    f.soundAmmoCheck = soundAmmoCheck

    local soundPetCheck = CreateFrame("CheckButton", nil, macrosPage, "UICheckButtonTemplate")
    soundPetCheck:SetSize(24, 24)
    soundPetCheck:SetPoint("TOPLEFT", soundAmmoCheck, "BOTTOMLEFT", 0, -4)
    soundPetCheck.text:SetText("Sound alert when pet is unhappy")
    soundPetCheck:SetScript("OnClick", function(self)
        Quiver.db.profile.sounds.petUnhappy = self:GetChecked()
    end)
    f.soundPetCheck = soundPetCheck

    -- ── Macro Generator ────────────────────────────────────────────────────────
    local macroSec = CreateFrame("Frame", nil, macrosPage)
    macroSec:SetWidth(COL_W)
    macroSec:SetHeight(MACRO_H)
    macroSec:SetPoint("TOPLEFT", soundPetCheck, "BOTTOMLEFT", 2, -GAP)

    local macroHdr = macroSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroHdr:SetPoint("TOPLEFT", macroSec, "TOPLEFT", 0, 0)
    macroHdr:SetText("Macro Generator")
    macroHdr:SetTextColor(1, 0.82, 0)

    local mt = Quiver.db.profile.macroTemplates

    local openLbl = macroSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    openLbl:SetPoint("TOPLEFT", macroHdr, "BOTTOMLEFT", 0, -6)
    openLbl:SetText("Quiver: Open  (pet attack + opening shot)")
    openLbl:SetTextColor(0.9, 0.9, 0.9)

    local openShotCtrl = MakeCycleControl(macroSec, "Shot:", SHOTS, mt.open_shot)
    openShotCtrl:SetPoint("TOPLEFT", openLbl, "BOTTOMLEFT", 0, -2)

    local bwLbl = macroSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bwLbl:SetPoint("TOPLEFT", openShotCtrl, "BOTTOMLEFT", 0, -6)
    bwLbl:SetText("Quiver: BW  (+ Intimidation in Tank Mode)")
    bwLbl:SetTextColor(0.9, 0.9, 0.9)

    local mdLbl = macroSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mdLbl:SetPoint("TOPLEFT", bwLbl, "BOTTOMLEFT", 0, -6)
    mdLbl:SetText("Quiver: MD  (Misdirection on focus)")
    mdLbl:SetTextColor(0.9, 0.9, 0.9)

    local createMacrosBtn = CreateFrame("Button", nil, macroSec, "UIPanelButtonTemplate")
    createMacrosBtn:SetWidth(150)
    createMacrosBtn:SetHeight(24)
    createMacrosBtn:SetText("Create / Update")
    createMacrosBtn:SetPoint("TOPLEFT", mdLbl, "BOTTOMLEFT", 0, -6)

    local deleteMacrosBtn = CreateFrame("Button", nil, macroSec, "UIPanelButtonTemplate")
    deleteMacrosBtn:SetWidth(80)
    deleteMacrosBtn:SetHeight(24)
    deleteMacrosBtn:SetText("Delete All")
    deleteMacrosBtn:SetPoint("LEFT", createMacrosBtn, "RIGHT", 4, 0)
    deleteMacrosBtn:SetScript("OnClick", function()
        local names = { "Quiver: Open", "Quiver: BW", "Quiver: MD", "Quiver: Sting" }
        local deleted = 0
        for _, name in ipairs(names) do
            local idx = GetMacroIndexByName(name)
            if idx > 0 then
                DeleteMacro(idx)
                deleted = deleted + 1
            end
        end
        if deleted > 0 then
            print("|cffffcc00Quiver:|r Deleted " .. deleted .. " macro(s).")
        else
            print("|cffffcc00Quiver:|r No Quiver macros found to delete.")
        end
    end)
    createMacrosBtn:SetScript("OnClick", function()
        local tmpl = Quiver.db.profile.macroTemplates
        tmpl.open_shot = openShotCtrl.GetValue()

        local shot = tmpl.open_shot
        local openLines = {
            "#showtooltip " .. shot,
            "/petfollow",
            "/petattack [harm]",
            "/cast [known:" .. shot .. "] " .. shot,
        }
        Quiver.UI.Menus:WriteManagedMacro("Quiver: Open", shot,           table.concat(openLines, "\n"))
        Quiver.UI.Menus:WriteManagedMacro("Quiver: BW",  "Bestial Wrath", Quiver.UI.Menus:BuildBWMacroBody())
        Quiver.UI.Menus:WriteManagedMacro("Quiver: MD",  "Misdirection",  "#showtooltip Misdirection\n/cast [target=focus] Misdirection")
        local stingSel = Quiver.db.char.menuSelections.stings
        if stingSel then
            Quiver.UI.Menus:UpdateStingMacro(stingSel)
        end
        print("|cffffcc00Quiver:|r Macros created. Drag them from your macro book to your action bars.")
    end)

    f.openShotCtrl = openShotCtrl

    -- ── ShowPage implementation (now all frames exist) ─────────────────────────
    ShowPage = function(name)
        for k, page in pairs(pages) do
            page:SetShown(k == name)
        end
        applyBtn:SetShown(name == "bindings")
        cancelBtn:SetShown(name == "bindings")
        for _, tb in ipairs(tabBtns) do
            local active = (tb.pageName == name)
            tb:GetFontString():SetTextColor(
                active and 1 or 0.5,
                active and 0.82 or 0.5,
                active and 0 or 0.5)
        end
    end

    ShowPage("bindings")
    f:Hide()
    return f
end

function Config:Toggle()
    if not panel then
        panel = Build()
    end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    local entries = GetSpellEntries()
    local sp      = Quiver.db.profile.sphere
    panel.lcSection:Refresh(entries, sp.leftType  or "spell", sp.leftClick,  sp.leftMacro  or "")
    panel.rcSection:Refresh(entries, sp.rightType or "spell", sp.rightClick, sp.rightMacro or "")
    panel.notifyCheck:SetChecked(Quiver.db.profile.notifications.petDied)
    panel.soundAmmoCheck:SetChecked(Quiver.db.profile.sounds.ammoLow)
    panel.soundPetCheck:SetChecked(Quiver.db.profile.sounds.petUnhappy)
    local mt = Quiver.db.profile.macroTemplates
    panel.openShotCtrl.SetValue(mt.open_shot)
    panel.ShowPage("bindings")
    panel:Show()
end
