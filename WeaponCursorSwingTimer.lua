-- Weapon Cursor Swing Timer: Swing-Timer als Kreis am Mauszeiger fuer WoW Forever
-- Nutzt das native PLAYER_SWING(swingDuration, swingType) Event (kein Combat-Log).
-- Die Dauer kann im Kampf ein "Secret Value" sein, deshalb wird sie nie in Lua
-- gerechnet, sondern direkt an einen Cooldown-Swipe uebergeben.

local ADDON, ns = ...
local L = ns.L
local PATH = "Interface\\AddOns\\" .. ADDON .. "\\"
ns.TITLE = "Weapon Cursor Swing Timer"
ns.PREFIX = "|cff66ccff" .. ns.TITLE .. "|r: "

ns.TEXTURES = {
    thin   = PATH .. "Ring_thin",
    normal = PATH .. "Ring",
    thick  = PATH .. "Ring_thick",
}

ns.ARROW_TEXTURE = PATH .. "Arrow"

-- Feste Symbole fuer die Ringe (unabhaengig von Klasse und Ausruestung).
-- Es geht ein Pfad oder eine FileID (Zahl).
ns.RING_INFO = {
    Main   = { name = L.RING_MAIN,    slot = 16, icon = 132400 },
    Off    = { name = L.RING_OFF,     slot = 17, icon = "Interface\\Icons\\INV_Shield_04" },
    Ranged = { name = L.RING_RANGED,  slot = 18, icon = "Interface\\Icons\\INV_Weapon_Bow_07" },
}
ns.RING_KEYS = { "Main", "Off", "Ranged" }

-- Account-weite Einstellungen
ns.defaults = {
    size       = 56,
    spacing    = 0.26,
    thickness  = "normal",
    offsetX    = 0,
    offsetY    = 0,
    alpha      = 1,
    combatOnly = true,
    reverse    = true,
    showReady  = true,
    colors = {
        Main   = { r = 1.00, g = 0.82, b = 0.20, a = 1.0 },
        Off    = { r = 0.40, g = 0.75, b = 1.00, a = 1.0 },
        Ranged = { r = 0.75, g = 1.00, b = 0.40, a = 1.0 },
        Ready  = { r = 0.25, g = 1.00, b = 0.35, a = 0.9 },
        Bg     = { r = 0.00, g = 0.00, b = 0.00, a = 0.55 },
    },
}

-- Pro Charakter: Reihenfolge (aussen -> innen) und sichtbare Ringe
function ns.ClassDefaultOrder()
    local _, class = UnitClass("player")
    if class == "HUNTER" then
        return { "Ranged", "Main", "Off" }
    end
    return { "Main", "Off", "Ranged" }
end

local function CharDefaults()
    return {
        order = ns.ClassDefaultOrder(),
        show  = { Main = true, Off = true, Ranged = true },
    }
end

local db, cdb
local rings = {}          -- key -> ring
local typeToRing = {}
local inCombat = false
local warnedFail = false
ns.preview = false
ns.rings = rings

local holder = CreateFrame("Frame", "WeaponCursorSwingTimerFrame", UIParent)
holder:SetFrameStrata("TOOLTIP")
holder:EnableMouse(false)
holder:Hide()

local issecret = issecretvalue or function() return false end
local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration

------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function ValidOrder(order)
    if type(order) ~= "table" or #order ~= 3 then return false end
    local seen = {}
    for _, k in ipairs(order) do
        if not ns.RING_INFO[k] or seen[k] then return false end
        seen[k] = true
    end
    return true
end

function ns.ResetDB()
    wipe(db)
    CopyDefaults(ns.defaults, db)
    wipe(cdb)
    CopyDefaults(CharDefaults(), cdb)
end

function ns.ResetOrder()
    cdb.order = ns.ClassDefaultOrder()
end

function ns.MoveRing(index, delta)
    local o = cdb.order
    local j = index + delta
    if j < 1 or j > #o then return end
    o[index], o[j] = o[j], o[index]
end

-- Liefert fuer jeden Key den Skalierungsfaktor (1 = aussen).
-- Ausgeblendete Ringe werden uebersprungen, die anderen ruecken nach aussen.
function ns.RingScales()
    local scales, idx = {}, 0
    for _, key in ipairs(cdb.order) do
        if cdb.show[key] then
            scales[key] = math.max(0.1, 1 - idx * db.spacing)
            idx = idx + 1
        end
    end
    return scales
end

------------------------------------------------------------
-- Ringe
------------------------------------------------------------
local function CreateRing(key)
    local r = CreateFrame("Frame", nil, holder)
    r:SetPoint("CENTER")
    r:EnableMouse(false)
    r.key = key

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()

    r.ready = r:CreateTexture(nil, "ARTWORK")
    r.ready:SetAllPoints()
    r.ready:Hide()

    local cd = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:EnableMouse(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    cd:SetScript("OnCooldownDone", function()
        if db.showReady then r.ready:Show() end
    end)
    r.cd = cd

    if CreateDuration then r.duration = CreateDuration() end
    r.active = false
    r:Hide()
    return r
end

function ns.ApplyLayout()
    if not db then return end
    local tex = ns.TEXTURES[db.thickness] or ns.TEXTURES.normal
    holder:SetSize(db.size, db.size)
    holder:SetAlpha(db.alpha)
    local bg, rd = db.colors.Bg, db.colors.Ready
    local scales = ns.RingScales()
    for key, r in pairs(rings) do
        local s = math.floor(db.size * (scales[key] or 1) + 0.5)
        r:SetSize(s, s)
        r.bg:SetTexture(tex)
        r.bg:SetVertexColor(bg.r, bg.g, bg.b, bg.a)
        r.ready:SetTexture(tex)
        r.ready:SetVertexColor(rd.r, rd.g, rd.b, rd.a)
        local c = db.colors[key]
        r.cd:SetSwipeTexture(tex)
        r.cd:SetSwipeColor(c.r, c.g, c.b, c.a)
        r.cd:SetReverse(db.reverse)
        if not db.showReady then r.ready:Hide() end
    end
end

function ns.UpdateVisibility()
    if not db then return end
    local any = false
    for key, r in pairs(rings) do
        local enabled = cdb.show[key]
        local show
        if ns.preview then
            show = enabled
        else
            show = r.active and enabled and (inCombat or not db.combatOnly)
        end
        r:SetShown(show and true or false)
        any = any or show
    end
    holder:SetShown(any and true or false)
end

local function StartRing(r, duration)
    r.ready:Hide()
    r.active = true
    local now = GetTime()
    local ok = false
    if r.duration and r.cd.SetCooldownFromDurationObject then
        ok = pcall(function()
            r.duration:SetTimeFromStart(now, duration)
            r.cd:SetCooldownFromDurationObject(r.duration)
        end)
    end
    if not ok then
        ok = pcall(r.cd.SetCooldown, r.cd, now, duration)
    end
    if not ok and not warnedFail then
        warnedFail = true
        print(ns.PREFIX .. L.SWING_FAIL)
    end
    ns.UpdateVisibility()
end

local function ClearRings()
    for _, r in pairs(rings) do
        r.active = false
        r.ready:Hide()
        r.cd:Clear()
    end
end

------------------------------------------------------------
-- Cursor folgen
------------------------------------------------------------
holder:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + db.offsetX, y / scale + db.offsetY)
end)

------------------------------------------------------------
-- Vorschau (laeuft solange das Optionsfenster offen ist)
------------------------------------------------------------
local previewTicker
local PREVIEW_SPEED = { Main = 2.6, Off = 1.8, Ranged = 3.0 }

function ns.SetPreview(on)
    if previewTicker then previewTicker:Cancel(); previewTicker = nil end
    ns.preview = on
    if on then
        local function swing()
            for key, r in pairs(rings) do StartRing(r, PREVIEW_SPEED[key]) end
        end
        swing()
        previewTicker = C_Timer.NewTicker(3.6, swing)
    else
        ClearRings()
    end
    ns.UpdateVisibility()
end

------------------------------------------------------------
-- Slash-Befehle
------------------------------------------------------------
local function Help()
    print(ns.PREFIX .. L.HELP_HEADER)
    print("  /wcst                   - " .. L.HELP_OPTIONS)
    print("  /wcst size <20-300>     - " .. L.HELP_SIZE)
    print("  /wcst offset <x> <y>    - " .. L.HELP_OFFSET)
    print("  /wcst combat            - " .. L.HELP_COMBAT)
    print("  /wcst reset             - " .. L.HELP_RESET)
end

SLASH_WEAPONCURSORSWINGTIMER1 = "/wcst"
SLASH_WEAPONCURSORSWINGTIMER2 = "/swc"
SlashCmdList.WEAPONCURSORSWINGTIMER = function(msg)
    local cmd, a, b = strsplit(" ", (msg or ""):lower():trim())
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.ToggleOptions()
        return
    elseif cmd == "size" and tonumber(a) then
        db.size = math.max(20, math.min(300, tonumber(a)))
    elseif cmd == "offset" and tonumber(a) and tonumber(b) then
        db.offsetX, db.offsetY = tonumber(a), tonumber(b)
    elseif cmd == "combat" then
        db.combatOnly = not db.combatOnly
        print(ns.PREFIX .. L.COMBAT_ONLY_STATE:format(db.combatOnly and L.ON or L.OFF))
    elseif cmd == "reset" then
        ns.ResetDB()
        print(ns.PREFIX .. L.RESET_DONE)
    else
        Help()
    end
    ns.ApplyLayout()
    ns.UpdateVisibility()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        WeaponCursorSwingTimerDB = WeaponCursorSwingTimerDB or {}
        WeaponCursorSwingTimerCharDB = WeaponCursorSwingTimerCharDB or {}
        db, cdb = WeaponCursorSwingTimerDB, WeaponCursorSwingTimerCharDB
        CopyDefaults(ns.defaults, db)
        CopyDefaults(CharDefaults(), cdb)
        if not ValidOrder(cdb.order) then cdb.order = ns.ClassDefaultOrder() end
        ns.db, ns.cdb = db, cdb

        for _, key in ipairs(ns.RING_KEYS) do rings[key] = CreateRing(key) end
        ns.ApplyLayout()
        if ns.InitOptions then ns.InitOptions() end

        local E = Enum and Enum.PlayerSwingType
        if not E then
            print(ns.PREFIX .. L.NO_API)
            return
        end
        typeToRing[E.MainHand] = rings.Main
        typeToRing[E.OffHand]  = rings.Off
        typeToRing[E.Ranged]   = rings.Ranged

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_SWING")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    elseif event == "PLAYER_SWING" then
        if ns.preview then return end
        local duration, swingType = ...
        if issecret(swingType) then return end
        local r = typeToRing[swingType]
        if r then StartRing(r, duration) end

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ns.UpdateVisibility()

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if db.combatOnly and not ns.preview then ClearRings() end
        ns.UpdateVisibility()

    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown() and true or false
        ns.UpdateVisibility()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if ns.RefreshOptions then ns.RefreshOptions() end -- Waffen-Icons
        if ns.preview then return end
        if slot == 16 then rings.Main.active = false; rings.Off.active = false end
        if slot == 17 then rings.Off.active = false end
        if slot == 18 then rings.Ranged.active = false end
        ns.UpdateVisibility()
    end
end)
