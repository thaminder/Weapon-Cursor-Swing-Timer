-- Weapon Cursor Swing Timer – Optionsfenster im WoW-Stil
local ADDON, ns = ...
local L = ns.L

local frame
local controls = {}

local GOLD = { 1, 0.82, 0 }

local function Apply()
    ns.ApplyLayout()
    ns.UpdateVisibility()
end

local function Register(c) table.insert(controls, c); return c end

local function Tooltip(widget, title, text)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", GameTooltip_Hide)
end

------------------------------------------------------------
-- Abschnitt mit Tooltip-Rahmen und goldener Ueberschrift
------------------------------------------------------------
local function Section(parent, title, w, h)
    local s = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    s:SetSize(w, h)
    s:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    s:SetBackdropColor(0.06, 0.06, 0.06, 0.75)
    s:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)

    local t = s:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    t:SetPoint("TOPLEFT", 12, -10)
    t:SetText(title)

    local line = s:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 10, -26)
    line:SetPoint("TOPRIGHT", -10, -26)
    line:SetHeight(1)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    return s
end

------------------------------------------------------------
-- Schieberegler (Blizzard-Template mit Pfeilen, sonst eigener)
------------------------------------------------------------
local function ManualSlider(parent, minV, maxV, step, onChange)
    local s = CreateFrame("Slider", nil, parent)
    s:SetSize(170, 16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
    track:SetColorTexture(0, 0, 0, 0.7)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 18)
    thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    s:SetThumbTexture(thumb)
    s:SetScript("OnValueChanged", function(_, v) onChange(v) end)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    return s, function(v) s:SetValue(v) end
end

local function BlizzSlider(parent, minV, maxV, step, value, onChange)
    if not MinimalSliderWithSteppersMixin then return nil end
    local ok, s = pcall(CreateFrame, "Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    if not ok or not s or not s.Init then return nil end
    s:SetWidth(200)
    local steps = math.floor((maxV - minV) / step + 0.5)
    if not pcall(s.Init, s, value, minV, maxV, steps) then s:Hide(); return nil end
    s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v) onChange(v) end, s)
    return s, function(v) s:SetValue(v) end
end

local function Slider(parent, label, key, minV, maxV, step, x, y, fmt, tip)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)

    local val = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    local loading = false
    local function show(v) val:SetText((fmt or "%d"):format(v)) end
    local function onChange(v)
        v = math.floor(v / step + 0.5) * step
        show(v)
        if loading then return end
        ns.db[key] = v
        Apply()
    end

    local s, set = BlizzSlider(parent, minV, maxV, step, ns.db[key], onChange)
    if not s then s, set = ManualSlider(parent, minV, maxV, step, onChange) end
    s:SetPoint("TOPLEFT", x, y - 16)
    val:SetPoint("LEFT", s, "RIGHT", 8, 0)
    if tip then Tooltip(s, label, tip) end

    return Register({ Refresh = function()
        loading = true
        set(ns.db[key]); show(ns.db[key])
        loading = false
    end })
end

------------------------------------------------------------
-- Checkbox
------------------------------------------------------------
local function Check(parent, label, x, y, get, set, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)
    local text = cb.Text or cb.text or cb:CreateFontString(nil, "ARTWORK")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
    cb:SetHitRectInsets(0, -text:GetStringWidth() - 4, 0, 0)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
    end)
    if tip then Tooltip(cb, label, tip) end
    cb.Refresh = function() cb:SetChecked(get()) end
    return Register(cb)
end

------------------------------------------------------------
-- Farbwaehler
------------------------------------------------------------
local function OpenColorPicker(c, onChange)
    local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
    local function read()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a
        if ColorPickerFrame.GetColorAlpha then
            a = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then
            a = 1 - OpacitySliderFrame:GetValue()
        end
        c.r, c.g, c.b = r, g, b
        if a then c.a = a end
        onChange()
    end
    local function cancel()
        c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
        onChange()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, opacity = c.a, hasOpacity = true,
            swatchFunc = read, opacityFunc = read, cancelFunc = cancel,
        })
    else
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - c.a
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = read, read, cancel
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
end

local function Swatch(parent, getColor, onChanged)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(20, 20)
    b:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.Refresh = function()
        local c = getColor()
        b:SetBackdropColor(c.r, c.g, c.b, math.max(c.a, 0.15))
    end
    b:SetScript("OnClick", function()
        OpenColorPicker(getColor(), function()
            b.Refresh(); Apply()
            if ns.RefreshPreview then ns.RefreshPreview() end
        end)
    end)
    Tooltip(b, L.CHANGE_COLOR, L.CHANGE_COLOR_TIP)
    return Register(b)
end

local function ColorRow(parent, label, colorKey, x, y)
    local sw = Swatch(parent, function() return ns.db.colors[colorKey] end)
    sw:SetPoint("TOPLEFT", x, y)
    local t = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    t:SetText(label)
end

local function Button(parent, text, w, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then Tooltip(b, text, tip) end
    return b
end

local function ArrowButton(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(24, 20)
    b:SetText("")
    -- eigene, exakt zentrierte Pfeilgrafik (Down = vertikal gespiegelt)
    local tex = b:CreateTexture(nil, "OVERLAY")
    tex:SetSize(12, 12)
    tex:SetPoint("CENTER")
    tex:SetTexture(ns.ARROW_TEXTURE)
    if dir == "Down" then tex:SetTexCoord(0, 1, 1, 0) end
    local function color(enabled)
        if enabled then tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        else tex:SetVertexColor(0.5, 0.5, 0.5, 0.6) end
    end
    color(true)
    b.icon = tex
    b:SetScript("OnClick", onClick)
    b:HookScript("OnDisable", function() color(false) end)
    b:HookScript("OnEnable",  function() color(true) end)
    b:HookScript("OnMouseDown", function(self)
        if self:IsEnabled() then tex:SetPoint("CENTER", 1, -1) end
    end)
    b:HookScript("OnMouseUp", function() tex:SetPoint("CENTER", 0, 0) end)
    Tooltip(b, dir == "Up" and L.MOVE_OUT or L.MOVE_IN)
    return b
end

------------------------------------------------------------
-- Ringliste + Vorschau
------------------------------------------------------------
local NUM_RINGS = #ns.RING_KEYS
local function PosLabel(i)
    local word = (i == 1 and L.POS_OUTER) or (i == NUM_RINGS and L.POS_INNER) or L.POS_MIDDLE
    return i .. " · " .. word
end

local function BuildRingSection(parent)
    local sec = Section(parent, L.SEC_RINGS, 716, 34 + NUM_RINGS * 42 + 6)

    local rows = {}
    for i = 1, NUM_RINGS do
        local row = CreateFrame("Frame", nil, sec)
        row.key = ns.cdb.order[i]
        row:SetSize(530, 38)
        row:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 42)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, i % 2 == 1 and 0.04 or 0.08)

        local pos = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        pos:SetPoint("LEFT", 8, 0)
        pos:SetWidth(88); pos:SetJustifyH("LEFT")
        pos:SetText(PosLabel(i))

        local iconBorder = row:CreateTexture(nil, "ARTWORK")
        iconBorder:SetSize(32, 32)
        iconBorder:SetPoint("LEFT", 96, 0)
        iconBorder:SetColorTexture(0, 0, 0, 1)
        local icon = row:CreateTexture(nil, "OVERLAY")
        icon:SetPoint("TOPLEFT", iconBorder, 1, -1)
        icon:SetPoint("BOTTOMRIGHT", iconBorder, -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        name:SetPoint("LEFT", iconBorder, "RIGHT", 10, 0)
        name:SetWidth(90); name:SetJustifyH("LEFT")

        local sw = Swatch(row, function() return ns.db.colors[row.key] end)
        sw:SetPoint("LEFT", 236, 0)

        local cb = Check(row, L.SHOW, 264, -7,
            function() return ns.cdb.show[row.key] end,
            function(v) ns.cdb.show[row.key] = v end,
            L.SHOW_TIP)

        -- Rahmen an/aus + Rahmenfarbe
        local bcb = Check(row, L.BORDER, 362, -7,
            function() return ns.db.border[row.key] end,
            function(v) ns.db.border[row.key] = v end,
            L.BORDER_TIP)
        local bsw = Swatch(row, function() return ns.db.borderColors[row.key] end)
        bsw:SetPoint("LEFT", 446, 0)

        local up = ArrowButton(row, "Up", function()
            ns.MoveRing(i, -1); Apply(); ns.RefreshOptions()
        end)
        up:SetPoint("RIGHT", -34, 0)
        local down = ArrowButton(row, "Down", function()
            ns.MoveRing(i, 1); Apply(); ns.RefreshOptions()
        end)
        down:SetPoint("RIGHT", -6, 0)

        row.Refresh = function()
            row.key = ns.cdb.order[i]
            local info = ns.RING_INFO[row.key]
            local c = ns.db.colors[row.key]
            icon:SetTexture(info.icon) -- feste Symbole, unabhaengig von Klasse/Ausruestung
            name:SetText(info.name)
            name:SetTextColor(c.r, c.g, c.b)
            local shown = ns.cdb.show[row.key]
            icon:SetDesaturated(not shown)
            icon:SetAlpha(shown and 1 or 0.5)
            up:SetEnabled(i > 1)
            down:SetEnabled(i < NUM_RINGS)
            sw.Refresh(); cb.Refresh(); bcb.Refresh(); bsw.Refresh()
            bsw:SetAlpha(ns.db.border[row.key] and 1 or 0.35)
        end
        rows[i] = Register(row)
    end

    -- Vorschau der Ringanordnung
    local pv = CreateFrame("Frame", nil, sec)
    pv:SetSize(120, 120)
    pv:SetPoint("TOPRIGHT", -30, -36)
    local pvBg = pv:CreateTexture(nil, "BACKGROUND")
    pvBg:SetPoint("CENTER"); pvBg:SetSize(128, 128)
    pvBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    pvBg:SetVertexColor(0, 0, 0, 0)
    local pvRings = {}
    for _, key in ipairs(ns.RING_KEYS) do
        local p = {}
        p.bg = pv:CreateTexture(nil, "BORDER")
        p.fg = pv:CreateTexture(nil, "ARTWORK", nil, 0)
        p.sh = pv:CreateTexture(nil, "ARTWORK", nil, 3)
        p.br = pv:CreateTexture(nil, "OVERLAY")
        for _, t in pairs(p) do t:SetPoint("CENTER") end
        pvRings[key] = p
    end
    local pvLabel = sec:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    pvLabel:SetPoint("TOP", pv, "BOTTOM", 0, -4)
    pvLabel:SetText(L.PREVIEW_LABEL)

    function ns.RefreshPreview()
        local db = ns.db
        local tex = ns.TEXTURES[db.thickness] or ns.TEXTURES.normal
        local btex = ns.BorderTexture(db.thickness, db.borderSize)
        local stex = ns.SHADOW_TEXTURES[db.thickness] or ns.SHADOW_TEXTURES.normal
        local sizes = ns.ComputeSizes(110, db.gap * 110 / db.size)
        local bgc = db.colors.Bg
        for key, p in pairs(pvRings) do
            local s = sizes[key]
            if s then
                local c, bc = db.colors[key], db.borderColors[key]
                p.bg:SetTexture(tex); p.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
                p.fg:SetTexture(tex); p.fg:SetVertexColor(c.r, c.g, c.b, c.a)
                p.sh:SetTexture(stex)
                p.br:SetTexture(btex); p.br:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
                for _, t in pairs(p) do t:SetSize(s, s); t:Show() end
                if not db.border[key] then p.sh:Hide(); p.br:Hide() end
            else
                for _, t in pairs(p) do t:Hide() end
            end
        end
    end
    Register({ Refresh = ns.RefreshPreview })
    return sec
end

------------------------------------------------------------
-- Fenster
------------------------------------------------------------
local function Build()
    local ok, f = pcall(CreateFrame, "Frame", "WeaponCursorSwingTimerOptions", UIParent, "PortraitFrameTemplate")
    if not ok then
        f = CreateFrame("Frame", "WeaponCursorSwingTimerOptions", UIParent, "BasicFrameTemplateWithInset")
    end
    frame = f
    f:SetSize(748, 606 + (NUM_RINGS - 3) * 42)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, "WeaponCursorSwingTimerOptions")

    local icon = "Interface\\Icons\\INV_Misc_PocketWatch_01"
    if f.SetTitle then f:SetTitle(ns.TITLE)
    elseif f.TitleText then f.TitleText:SetText(ns.TITLE) end
    if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, icon)
    elseif f.PortraitContainer and f.PortraitContainer.portrait then
        SetPortraitToTexture(f.PortraitContainer.portrait, icon)
    end

    -- Untertitel
    local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 68, -34)
    sub:SetText(L.SUBTITLE)

    -- Ringe
    local rs = BuildRingSection(f)
    rs:SetPoint("TOPLEFT", 16, -58)

    -- Darstellung
    local look = Section(f, L.SEC_LOOK, 354, 328)
    look:SetPoint("TOPLEFT", rs, "BOTTOMLEFT", 0, -8)
    Slider(look, L.SIZE,     "size",    20, 300, 1,      16, -36,  "%d px", L.SIZE_TIP)
    Slider(look, L.SPACING,  "gap",     0, 20, 1,        16, -82,  "%d px", L.SPACING_TIP)
    Slider(look, L.ALPHA,    "alpha",   0.1, 1, 0.05,    16, -128, "%.2f")
    Slider(look, L.OFFSET_X, "offsetX", -200, 200, 1,    16, -174, "%d", L.OFFSET_X_TIP)
    Slider(look, L.OFFSET_Y, "offsetY", -200, 200, 1,    16, -220, "%d", L.OFFSET_Y_TIP)
    Slider(look, L.BORDER_SIZE, "borderSize", 1, 5, 1,   16, -266, "%d / 5", L.BORDER_SIZE_TIP)

    -- Allgemein
    local gen = Section(f, L.SEC_GENERAL, 354, 328)
    gen:SetPoint("TOPLEFT", look, "TOPRIGHT", 8, 0)

    local th = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    th:SetPoint("TOPLEFT", 14, -36)
    th:SetText(L.THICKNESS)
    local thickBtns = {}
    for i, o in ipairs({ { "thin", L.THIN }, { "normal", L.NORMAL }, { "thick", L.THICK } }) do
        local b = Button(gen, o[2], 80, function()
            ns.db.thickness = o[1]
            Apply(); ns.RefreshOptions()
        end)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -54)
        thickBtns[i] = Register({ Refresh = function() b:SetEnabled(ns.db.thickness ~= o[1]) end })
    end

    ColorRow(gen, L.READY_COLOR, "Ready", 16, -88)
    ColorRow(gen, L.BG_COLOR,    "Bg",    160, -88)

    Check(gen, L.COMBAT_ONLY, 12, -118,
        function() return ns.db.combatOnly end, function(v) ns.db.combatOnly = v end)
    Check(gen, L.REVERSE, 12, -144,
        function() return ns.db.reverse end, function(v) ns.db.reverse = v end,
        L.REVERSE_TIP)
    Check(gen, L.SHOW_READY, 12, -170,
        function() return ns.db.showReady end, function(v) ns.db.showReady = v end,
        L.SHOW_READY_TIP)

    local native = Check(gen, L.HIDE_NATIVE, 12, -196,
        function()
            local ok2, v = pcall(GetCVar, "showSwingTimer")
            return ok2 and v == "0"
        end,
        function(v)
            if InCombatLockdown() then
                print(ns.PREFIX .. L.NOT_IN_COMBAT)
                return
            end
            pcall(SetCVar, "showSwingTimer", v and "0" or "1")
        end,
        L.HIDE_NATIVE_TIP)

    -- Fusszeile
    local reset = Button(f, L.DEFAULTS, 130, function()
        StaticPopup_Show("WCST_RESET")
    end, L.DEFAULTS_TIP)
    reset:SetPoint("BOTTOMLEFT", 16, 14)

    local classBtn = Button(f, L.CLASS_ORDER, 150, function()
        ns.ResetOrder(); Apply(); ns.RefreshOptions()
    end, L.CLASS_ORDER_TIP)
    classBtn:SetPoint("LEFT", reset, "RIGHT", 6, 0)

    local close = Button(f, CLOSE or "Close", 110, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 14)

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("RIGHT", close, "LEFT", -12, 0)
    hint:SetText(L.LIVE_PREVIEW)

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
        ns.RefreshOptions()
        ns.SetPreview(true)
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
        ns.SetPreview(false)
    end)

    StaticPopupDialogs["WCST_RESET"] = {
        text = L.RESET_CONFIRM:format(ns.TITLE),
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() ns.ResetDB(); Apply(); ns.RefreshOptions() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end

function ns.RefreshOptions()
    if not frame or not frame:IsShown() then return end
    for _, c in ipairs(controls) do c.Refresh() end
end

function ns.ToggleOptions()
    if not frame then Build() end
    frame:SetShown(not frame:IsShown())
end

------------------------------------------------------------
-- Eintrag in Optionen > AddOns
------------------------------------------------------------
function ns.InitOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(ns.TITLE)
    local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText(L.SETTINGS_DESC)
    local b = Button(panel, L.OPEN_OPTIONS, 160, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if not frame then Build() end
        frame:Show()
    end)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -16)
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
end
