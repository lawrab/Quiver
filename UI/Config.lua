-- Config panel: sphere left/right click bindings.
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
local SECTION_H = HDR_H + TABS_H + CONTENT_H
local GAP       = 12
local PANEL_W   = COL_W + PADDING * 2
local NOTIFY_H  = 28
local PANEL_H   = 46 + SECTION_H + GAP + SECTION_H + GAP + NOTIFY_H + 46

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

    -- Section header
    local hdr = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT")
    hdr:SetText(labelText)
    hdr:SetTextColor(1, 0.82, 0)

    -- ── Tab buttons ─────────────────────────────────────────────────────────
    local TAB_W   = math.floor(COL_W / 3) - 2
    local tabDefs = { "spell", "macro", "none" }
    local tabBtns = {}

    local spellFrame, macroFrame, noneFrame, macroEB  -- forward-declared

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

    -- ── Spell scroll list ────────────────────────────────────────────────────
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
    content:SetHeight(ITEM_H)  -- resized in Refresh
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

        -- Scripts reference b.spellId directly so they stay correct across refreshes.
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

    -- ── Macro EditBox ────────────────────────────────────────────────────────
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

    -- ── None placeholder ─────────────────────────────────────────────────────
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

    -- ── Refresh ──────────────────────────────────────────────────────────────
    -- Syncs button pool to current entries and resets selection state.
    -- Called each time the panel opens — frames are reused, never recreated.
    function container:Refresh(entries, initType, initSpell, initMacro)
        currentType   = initType  or "spell"
        selectedSpell = initSpell or "none"
        macroEB:SetText(initMacro or "")

        -- Grow the button pool if the spell list has expanded since last open.
        for i = #allBtns + 1, #entries do
            allBtns[i] = MakeListButton(i)
        end

        -- Update visible buttons with current entry data.
        content:SetHeight(#entries * ITEM_H)
        for i, entry in ipairs(entries) do
            local b = allBtns[i]
            b.spellId = entry.id
            b.txt:SetText(entry.label)
            b:Show()
        end
        -- Hide pool slots beyond current entry count.
        for i = #entries + 1, #allBtns do
            allBtns[i]:Hide()
        end

        RefreshHL()

        -- Scroll to show the selected entry.
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

    local lcSection = MakeBindingSection(f, "Left Click")
    lcSection:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -42)
    f.lcSection = lcSection

    local rcSection = MakeBindingSection(f, "Right Click")
    rcSection:SetPoint("TOPLEFT", lcSection, "BOTTOMLEFT", 0, -GAP)
    f.rcSection = rcSection

    local notifyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    notifyCheck:SetSize(24, 24)
    notifyCheck:SetPoint("TOPLEFT", rcSection, "BOTTOMLEFT", -2, -GAP)
    notifyCheck.text:SetText("Notify in chat when pet dies")
    notifyCheck:SetScript("OnClick", function(self)
        Quiver.db.profile.notifications.petDied = self:GetChecked()
    end)
    f.notifyCheck = notifyCheck

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
    panel:Show()
end
