-- KeebUI: shared helpers, saved settings, movable anchors.
-- WoW Forever runs the modern retail engine: in combat many values (health,
-- power, aura details) are "secret" and may only be handed straight to widgets,
-- never compared or used in arithmetic. Everything here is written around that.

local ADDON, ns = ...

local DEFAULTS = {
    unitFrames = true,  -- player, target, target of target, pet
    party = true,
    raid = true,
    bars = true,        -- restyle the built-in action buttons in place
    castSwing = true,   -- built-in cast bar and swing timer
    chrome = true,      -- slim XP bar, flat menu buttons, quieter quest tracker
    tracker = true,     -- scrollable quest list in place of the built-in tracker
    skin = true,        -- flat tooltip
    raidTools = true,   -- ready check / pull timer / marks bar, and the mark ring
    plates = true,      -- flat nameplates
    trinkets = true,    -- two trinket buttons with a bag pop-up
    fiveSecond = true,  -- five-second-rule marker on your mana bar
    blizzClassColor = true, -- with Blizzard's own unit frames: class / reaction colour on their health bars
    transmute = false,  -- tell me when the Arcanite transmute is off cooldown
    combo = "target",   -- combo points: "target", "player", "bars" or "off"
    font = true,        -- the cast bar's easy-to-read font across the game
    scale = 1,
    pos = {},           -- [anchor key] = { x, y } : x from screen centre, y from screen bottom
    errors = {},        -- first few errors, kept for troubleshooting
}

ns.TEX = "Interface\\Buttons\\WHITE8x8" -- every bar is a flat fill, no gloss
ns.FLAT = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_FONT = "Fonts\\ARIALN.TTF" -- plain narrow sans-serif: reads well at any size
ns.FONT = DEFAULT_FONT -- replaced by your choice once settings load

-- The fonts on offer: the ones the game ships, plus any that other addons
-- have registered with the shared media library, plus a path you typed.
-- Other addons register fonts that this game client may not actually have
-- (Chinese and Korean faces, mostly). Those draw as nothing at all, so each
-- one is tried on a hidden line of text first and left out if it comes up empty.
local fontProbe
local function FontDraws(path)
    if not fontProbe then
        fontProbe = UIParent:CreateFontString(nil, "ARTWORK")
        fontProbe:Hide()
    end
    local ok, set = pcall(fontProbe.SetFont, fontProbe, path, 13, "")
    if not ok or set == false then return false end
    fontProbe:SetText("Abc 123")
    local okWidth, width = pcall(fontProbe.GetStringWidth, fontProbe)
    return okWidth and type(width) == "number" and width > 1
end

function ns.Fonts()
    local list = {
        { "Arial Narrow", DEFAULT_FONT },
        { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
        { "Morpheus", "Fonts\\MORPHEUS.TTF" },
        { "Skurri", "Fonts\\SKURRI.TTF" },
    }
    local seen = {}
    for _, f in ipairs(list) do seen[f[2]:lower()] = true end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = {}
        for name in pairs(lsm:HashTable("font") or {}) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local path = lsm:Fetch("font", name, true)
            if type(path) == "string" and not seen[path:lower()] then
                seen[path:lower()] = true
                if FontDraws(path) then list[#list + 1] = { name, path } end
            end
        end
    end
    local mine = ns.db and ns.db.fontFace
    if type(mine) == "string" and not seen[mine:lower()] then
        list[#list + 1] = { mine:match("([^\\/]+)%.[%a]+$") or mine, mine }
    end
    return list
end
ns.MEDIA = "Interface\\AddOns\\KeebUI\\Media\\"
ns.db = DEFAULTS
ns.modules = {}

local isSecret = issecretvalue or function() return false end
ns.IsSecret = isSecret

-- A value that is safe to compare, or nil when the game is hiding it.
function ns.Clean(value)
    if isSecret(value) then return nil end
    return value
end

-- One of the bars on Blizzard's own player or target frame, wherever this
-- client keeps it. which: "player" / "target" / "targettarget";
-- kind: "healthbar" / "manabar". Nil when it cannot be found.
function ns.BlizzBar(which, kind)
    local health = kind == "healthbar"
    local bar
    if which == "targettarget" then
        local tot = _G.TargetFrameToT or (_G.TargetFrame and _G.TargetFrame.totFrame)
        bar = tot and (tot[kind] or tot[health and "HealthBar" or "ManaBar"])
    else
        local prefix = which == "player" and "PlayerFrame" or "TargetFrame"
        local frame = _G[prefix]
        if not frame then return nil end
        bar = frame[kind]
        if not bar then
            local getter = _G[prefix .. "_Get" .. (health and "HealthBar" or "ManaBar")]
            if type(getter) == "function" then
                local ok, found = pcall(getter)
                if ok then bar = found end
            end
        end
        bar = bar or _G[prefix .. (health and "HealthBar" or "ManaBar")]
    end
    if type(bar) == "table" and bar.SetStatusBarColor then return bar end
    return nil
end

-- Every game setting KeebUI changes goes through here: the value it had
-- before is remembered the first time, so "Restore my old UI" can put it back.
function ns.SetCVar(name, value)
    local okGet, now = pcall(GetCVar, name)
    if not okGet or now == nil then return false, "no such setting" end
    if tostring(now) == tostring(value) then return true end
    if ns.db then
        ns.db.cvarBackup = type(ns.db.cvarBackup) == "table" and ns.db.cvarBackup or {}
        if ns.db.cvarBackup[name] == nil then ns.db.cvarBackup[name] = tostring(now) end
    end
    return pcall((C_CVar and C_CVar.SetCVar) or SetCVar, name, value)
end

-- The pieces a new user picks from on the welcome screen, and that
-- "Restore my old UI" switches off again.
ns.PIECES = {
    { "Unit frames", "Player, target, target of target and pet", { "unitFrames" } },
    { "Party and raid frames", "A party column and a raid grid", { "party", "raid" } },
    { "Action bars", "Flat rounded buttons, bars stacked bottom centre. Added as a new Edit Mode layout; yours is kept", { "bars" } },
    { "Nameplates", "Flat bars with class and threat colours", { "plates" } },
    { "Cast bar and swing timer", "", { "castSwing" } },
    { "Flat tooltip", "A plain dark panel with a thin edge", { "skin" } },
    { "Quest list, XP bar and bags", "Scrollable quest list, slim XP bar, equipment-set highlight", { "chrome", "tracker" } },
    { "Readable font everywhere", "One clean font across the game's own text", { "font" } },
    { "Extras", "Trinket buttons and raid tools", { "trinkets", "raidTools" } },
}

-- Puts back every game setting KeebUI changed and the Edit Mode layout you
-- were on, switches every piece off, and reloads. The welcome screen comes
-- up again afterwards, in case you want some of it back.
function ns.RestoreOldUI()
    if InCombatLockdown() then
        ns.Print("can't do that in combat.")
        return
    end
    for name, value in pairs(ns.db.cvarBackup or {}) do
        pcall((C_CVar and C_CVar.SetCVar) or SetCVar, name, value)
    end
    ns.db.cvarBackup = nil
    if ns.RestoreLayout then pcall(ns.RestoreLayout) end
    for _, piece in ipairs(ns.PIECES) do
        for _, key in ipairs(piece[3]) do ns.db[key] = false end
    end
    ns.db.setupDone = false
    ns.db.layoutVersion = nil
    ReloadUI()
end

-- Where combo points go, or nil on a class that has none (or when switched off).
function ns.ComboPlace()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" and class ~= "DRUID" then return nil end
    local place = ns.db.combo
    if place == "target" or place == "player" or place == "bars" then return place end
    return nil
end

-- Make a container-drawn aura icon show its tooltip on hover, in and out of
-- combat. The time-left sweep is a frame of its own lying over the icon; left
-- alone it swallows the mouse, so every aura with a timer had no tooltip.
function ns.AuraTooltip(button, cooldown)
    if cooldown then
        cooldown:EnableMouse(false)
        if cooldown.SetMouseClickEnabled then cooldown:SetMouseClickEnabled(false) end
        if cooldown.SetMouseMotionEnabled then cooldown:SetMouseMotionEnabled(false) end
    end
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, true) end
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end -- clicks pass through
    if button.SetTooltipAnchorPoint then pcall(button.SetTooltipAnchorPoint, button, "ANCHOR_BOTTOMRIGHT") end
    if button.SetHideTooltipInCombat then pcall(button.SetHideTooltipInCombat, button, false) end
end

-- Classes that fight with a pet out. For them the pet frame sits directly
-- under the player frame and the swing timer moves above it.
function ns.PetClass()
    local _, class = UnitClass("player")
    return class == "HUNTER" or class == "WARLOCK"
end

function ns.Print(msg)
    print("|cff33ff99KeebUI:|r " .. msg)
end

---------------------------------------------------------------------------
-- Error capture: a broken update must never spam or break the frames.
---------------------------------------------------------------------------
local errorCount = 0

function ns.LogError(label, err)
    local log = ns.db.errors
    if not log or errorCount >= 20 then return end
    local key = label .. ": " .. tostring(err)
    if log[key] then return end
    log[key] = date("%Y-%m-%d %H:%M")
    errorCount = errorCount + 1
    if errorCount == 1 then
        ns.Print("something went wrong (" .. label .. "). Type /keebui errors to see it.")
    end
end

-- The game's own error reports (the red error window, and "an addon tried
-- to do something it is not allowed to") are not written to disk anywhere.
-- Keep the first few here, with the settings, so they can be read back.
do
    local seen, count = {}, 0
    local function Keep(kind, text)
        local log = ns.db and ns.db.gameErrors
        if not log or count >= 15 then return end
        text = tostring(text):sub(1, 1500)
        if seen[text] then return end
        seen[text] = true
        count = count + 1
        log[#log + 1] = kind .. " @ " .. date("%H:%M:%S") .. ": " .. text
    end
    ns.KeepGameError = Keep

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    pcall(watcher.RegisterEvent, watcher, "LUA_WARNING")
    watcher:SetScript("OnEvent", function(_, event, a, b)
        Keep(event, tostring(a) .. " | " .. tostring(b))
    end)

    -- pass every error on to whatever was handling it before; just take a copy
    local previous = geterrorhandler()
    seterrorhandler(function(message, ...)
        local ok, stack = pcall(debugstack, 2, 12, 0)
        pcall(Keep, "error", tostring(message) .. (ok and stack and ("\n" .. stack) or ""))
        if previous then return previous(message, ...) end
    end)
end

function ns.Safe(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then ns.LogError(label, err) end
    end
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
-- White text, black outline, hard black shadow: the cast bar's recipe.
function ns.SetFont(fs, size)
    if not fs:SetFont(ns.FONT, size, "OUTLINE") then
        fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    end
end

function ns.Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns.SetFont(fs, size)
    fs:SetTextColor(1, 1, 1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- 1px black outline around a frame, filled black behind its contents.
function ns.Edge(frame)
    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    return edge
end

function ns.Bar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.TEX)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.07, 0.07, 1)
    return bar
end

-- Incoming heals: a translucent green stretch that starts where the health
-- fill ends. It is a second bar hung on the end of the fill and measured on
-- the same scale (0 to max health), so the game does the arithmetic and the
-- numbers never have to be read here. Anything past full health is clipped.
function ns.HealPrediction(health)
    health:SetClipsChildren(true)
    local incoming = CreateFrame("StatusBar", nil, health)
    incoming:SetStatusBarTexture(ns.FLAT)
    incoming:SetStatusBarColor(0.35, 0.95, 0.45, 0.55)
    incoming:SetFrameLevel(health:GetFrameLevel() + 1)
    local fill = health:GetStatusBarTexture()
    incoming:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    incoming:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
    incoming:SetWidth(math.max(health:GetWidth() or 0, 1))
    health:HookScript("OnSizeChanged", function(_, width)
        if width and width > 0 then incoming:SetWidth(width) end
    end)
    incoming:SetMinMaxValues(0, 1)
    incoming:SetValue(0)
    return incoming
end

function ns.UpdateHealPrediction(incoming, unit)
    if not incoming then return end
    local amount = UnitGetIncomingHeals and UnitGetIncomingHeals(unit)
    incoming:SetMinMaxValues(0, UnitHealthMax(unit))
    if ns.IsSecret(amount) or amount then
        incoming:SetValue(amount)
    else
        incoming:SetValue(0)
    end
end

-- 2px coloured frame drawn just inside a cell (dispel / aggro / target marks).
function ns.InnerBorder(parent)
    local b = { parts = {} }
    local function part(p1, p2, w, h)
        local t = parent:CreateTexture(nil, "OVERLAY", nil, 1)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        t:Hide()
        b.parts[#b.parts + 1] = t
    end
    part("TOPLEFT", "TOPRIGHT", nil, 2)
    part("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    part("TOPLEFT", "BOTTOMLEFT", 2)
    part("TOPRIGHT", "BOTTOMRIGHT", 2)
    function b:Show(r, g, bl)
        for _, t in ipairs(self.parts) do
            t:SetVertexColor(r, g, bl)
            t:Show()
        end
    end
    function b:Hide()
        for _, t in ipairs(self.parts) do t:Hide() end
    end
    return b
end

-- Colour for a unit's level text: how hard that unit is for you.
-- Quests and creatures are graded differently by the game (a mob can still be
-- worth fighting at a level where a quest would already be grey), so this
-- asks the creature grading first and only falls back to the quest one.
function ns.LevelColor(unit, level)
    if ns.Clean(UnitIsUnit(unit, "player")) then return 1, 0.82, 0 end
    if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
        local ok, difficulty = pcall(C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        difficulty = ok and ns.Clean(difficulty)
        if difficulty then
            local c = GetDifficultyColor(difficulty)
            if c then return c.r, c.g, c.b end
        end
    end
    if level and level > 0 then
        local c = (GetCreatureDifficultyColor and GetCreatureDifficultyColor(level))
            or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.2, 0.2 -- skull level
end

-- Class colour for players, reaction colour for everything else.
-- A player's class colour: r, g, b, or nil for anything that is not a player.
--
-- In battlegrounds the game hides who an enemy is from addons: "is this a
-- player" and "what class" come back as values that cannot be looked at,
-- only handed on. In that case the class is handed straight to the game's
-- own colour lookup and the result straight to the bar, never inspected.
-- The fourth result is true when that happened (the numbers are then hidden
-- too: fine to give to a bar, not to do sums with).
function ns.ClassColorOf(unit)
    local isPlayer = UnitIsPlayer(unit)
    if isSecret(isPlayer) then
        local ok, r, g, b = pcall(function()
            local _, class = UnitClass(unit)
            local c = C_ClassColor.GetClassColor(class)
            return c.r, c.g, c.b
        end)
        if ns.db then ns.db.bgProbe = { hidden = true, worked = ok, why = (not ok) and tostring(r) or nil } end
        if ok then return r, g, b, true end
        return nil
    end
    if not isPlayer then return nil end
    local _, class = UnitClass(unit)
    if isSecret(class) then
        local ok, r, g, b = pcall(function()
            local c = C_ClassColor.GetClassColor(class)
            return c.r, c.g, c.b
        end)
        if ns.db then ns.db.bgProbe = { hiddenClass = true, worked = ok, why = (not ok) and tostring(r) or nil } end
        if ok then return r, g, b, true end
        return nil
    end
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return nil
end

function ns.UnitColor(unit)
    local Clean = ns.Clean
    local r, g, b, hidden = ns.ClassColorOf(unit)
    if hidden then return r, g, b end
    if r then return r * 0.85, g * 0.85, b * 0.85 end
    if UnitIsTapDenied and Clean(UnitIsTapDenied(unit)) then return 0.5, 0.5, 0.5 end
    local reaction = Clean(UnitReaction(unit, "player"))
    if reaction then
        if reaction >= 5 then return 0.2, 0.7, 0.25 end
        if reaction == 4 then return 0.85, 0.75, 0.2 end
        return 0.8, 0.22, 0.2
    end
    return 0.2, 0.7, 0.25
end

---------------------------------------------------------------------------
-- Aura icons (shared by the target frame and party cells)
---------------------------------------------------------------------------
function ns.AuraIcon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    ns.Edge(f)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints()
    f.cd:SetDrawEdge(false)
    f.cd:SetReverse(true)
    f.cd:EnableMouse(false) -- or the sweep swallows the hover and the tooltip never shows
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f.cd:GetFrameLevel() + 1)
    f.count = ns.Text(top, 13, "RIGHT")
    f.count:SetPoint("BOTTOMRIGHT", 1, 0)
    f:SetScript("OnEnter", function(self)
        if not self.unit or not self.auraID then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        local setter = self.harmful and GameTooltip.SetUnitDebuffByAuraInstanceID
            or GameTooltip.SetUnitBuffByAuraInstanceID
        if setter and pcall(setter, GameTooltip, self.unit, self.auraID) then
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- hover for the tooltip only; clicks pass through to whatever is underneath
    if f.SetMouseClickEnabled then f:SetMouseClickEnabled(false) end
    f:Hide()
    return f
end

local function ShowAura(icon, unit, aura, harmful)
    icon.unit, icon.auraID, icon.harmful = unit, aura.auraInstanceID, harmful
    icon.icon:SetTexture(aura.icon)

    local timed = false
    if C_UnitAuras.GetAuraDuration and icon.cd.SetCooldownFromDurationObject then
        local ok, duration = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
        if ok and duration then
            timed = pcall(icon.cd.SetCooldownFromDurationObject, icon.cd, duration)
        end
    end
    icon.cd:SetShown(timed)

    -- The stack text may be hidden from addons, so it goes straight to the label.
    local ok, text
    if C_UnitAuras.GetAuraApplicationDisplayCount then
        ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, aura.auraInstanceID, 2, 99)
    end
    if ok then
        icon.count:SetText(text)
    else
        icon.count:SetText("")
    end
    icon:Show()
end

ns.ShowAura = ShowAura

-- A unit's auras as a list, by whichever route the game allows. Asking for
-- them one index at a time is refused for some units on this client, so two
-- other routes are tried after it. The first refusal from each route is kept
-- under /keebui errors so it can be looked at.
local function ListAuras(unit, filter, limit)
    local list = {}
    if not (C_UnitAuras and UnitExists(unit)) then return list end

    if C_UnitAuras.GetAuraDataByIndex then
        local failed = false
        for i = 1, limit do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok then
                ns.LogError("auras by index (" .. unit .. " " .. filter .. ")", aura)
                failed = true
                break
            end
            if not aura then break end
            list[#list + 1] = aura
        end
        if #list > 0 or not failed then
            if #list > 0 then return list end
        end
    end

    if C_UnitAuras.GetUnitAuras then
        local ok, all = pcall(C_UnitAuras.GetUnitAuras, unit, filter, limit)
        if ok and type(all) == "table" then
            for i = 1, math.min(#all, limit) do list[#list + 1] = all[i] end
            if #list > 0 then return list end
        elseif not ok then
            ns.LogError("auras as list (" .. unit .. " " .. filter .. ")", all)
        end
    end

    if C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        local ok, err = pcall(function()
            local slots = { C_UnitAuras.GetAuraSlots(unit, filter, limit) }
            for i = 2, #slots do -- the first value is a continuation token
                local aura = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
                if aura and #list < limit then list[#list + 1] = aura end
            end
        end)
        if not ok then ns.LogError("auras by slot (" .. unit .. " " .. filter .. ")", err) end
    end
    return list
end
ns.ListAuras = ListAuras

-- Fill a row of icons from the unit's auras. Returns how many are showing.
function ns.FillAuras(icons, unit, filter)
    local harmful = filter:find("HARMFUL", 1, true) ~= nil
    local list = ListAuras(unit, filter, #icons)
    for i, aura in ipairs(list) do
        ShowAura(icons[i], unit, aura, harmful)
    end
    for i = #list + 1, #icons do icons[i]:Hide() end
    -- a one-time note of how many were found on a hostile target, for troubleshooting
    if unit == "target" and harmful and ns.db and InCombatLockdown() then
        local probe = ns.db.targetAuraProbe
        if type(probe) ~= "table" or probe.checks == nil then
            probe = { most = 0, checks = 0 }
            ns.db.targetAuraProbe = probe
        end
        probe.checks = probe.checks + 1
        if #list > probe.most then probe.most = #list end
    end
    return #list
end

---------------------------------------------------------------------------
-- Right-click menus. On this client a unit button cannot open the menu
-- itself, so right-click presses a tiny hidden helper button that does.
---------------------------------------------------------------------------
local menuCount = 0

function ns.AttachMenu(button)
    menuCount = menuCount + 1
    local name = "KeebUIMenuButton" .. menuCount
    local helper = CreateFrame("Button", name, button, "SecureActionButtonTemplate")
    helper:SetSize(1, 1)
    helper:SetAlpha(0)
    helper:EnableMouse(false)
    helper:RegisterForClicks("AnyUp")
    helper:SetAttribute("useparent-unit", true)
    helper:SetAttribute("useOnKeyDown", false)
    helper:SetAttribute("type", "togglemenu")
    for i = 1, 5 do helper:SetAttribute("type" .. i, "togglemenu") end
    button:SetAttribute("*type2", "macro")
    button:SetAttribute("*macrotext2", "/click " .. name)
    return name
end

---------------------------------------------------------------------------
-- Click-casting on party and raid frames. Each mouse button, alone or with
-- Shift, Ctrl or Alt, can be given one of: "target", "menu" (the right-click
-- menu), or the name of a spell to cast on that member.
---------------------------------------------------------------------------
ns.CLICK_BUTTONS = { { 1, "Left" }, { 2, "Right" }, { 3, "Middle" } }
ns.CLICK_MODS = { { "", "" }, { "shift-", "Shift + " }, { "ctrl-", "Ctrl + " }, { "alt-", "Alt + " } }

-- The saved bindings: ["shift-2"] = "Flash of Light", ["1"] = "target", ...
function ns.ClickCasts()
    local db = ns.db
    if type(db.clickCast) ~= "table" then
        db.clickCast = { ["1"] = "target", ["2"] = "menu" }
        -- carried over from the earlier single right-click setting
        if type(db.rightClick) == "string" and db.rightClick ~= "" then
            db.clickCast["2"] = db.rightClick
            db.clickCast["shift-2"] = "menu"
        end
        db.rightClick = nil
    end
    return db.clickCast
end

---------------------------------------------------------------------------
-- Retiring built-in frames (only ever out of combat)
---------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local retireQueue = {}

function ns.Retire(frame, children)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame then return end
    if InCombatLockdown() then
        retireQueue[frame] = children or true
        return
    end
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:SetParent(hiddenParent)
    if type(children) == "table" then
        for _, key in ipairs(children) do
            local child = frame[key] or _G[key]
            if child and child.UnregisterAllEvents then child:UnregisterAllEvents() end
        end
    end
end

---------------------------------------------------------------------------
-- Anchors: plain frames that hold a position; the real frames sit on them.
---------------------------------------------------------------------------
ns.anchors = {}
local unlocked = false

local function PlaceAnchor(anchor)
    if InCombatLockdown() then return end
    local scale = ns.db.scale or 1
    local saved = ns.db.pos[anchor.key]
    local x = saved and saved[1] or anchor.defaultX
    local y = saved and saved[2] or anchor.defaultY
    anchor:SetScale(scale)
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "BOTTOM", x / scale, y / scale)
end

function ns.Anchor(key, label, width, height, x, y)
    local anchor = CreateFrame("Frame", "KeebUIAnchor_" .. key, UIParent)
    anchor.key, anchor.defaultX, anchor.defaultY = key, x, y
    anchor:SetSize(width, height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)

    local mover = CreateFrame("Frame", nil, anchor)
    mover:SetAllPoints()
    mover:SetFrameStrata("DIALOG")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    local fill = mover:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.1, 0.6, 0.3, 0.55)
    local text = ns.Text(mover, 11, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label)
    anchor.labelText = text
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then anchor:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        anchor:SetUserPlaced(false)
        local scale = anchor:GetScale()
        local cx, cy = anchor:GetCenter()
        local ux = UIParent:GetCenter()
        if cx and ux then
            ns.db.pos[anchor.key] = { cx * scale - ux, cy * scale } -- anchor.key: the raid block has one spot per size
        end
        PlaceAnchor(anchor)
    end)
    anchor.mover = mover

    ns.anchors[#ns.anchors + 1] = anchor
    PlaceAnchor(anchor)
    return anchor
end

function ns.PlaceAnchors()
    for _, anchor in ipairs(ns.anchors) do PlaceAnchor(anchor) end
end

function ns.SetUnlocked(state)
    if state and InCombatLockdown() then
        ns.Print("can't move frames in combat.")
        return
    end
    unlocked = state and true or false
    for _, anchor in ipairs(ns.anchors) do
        if not unlocked then anchor:StopMovingOrSizing() end
        anchor.mover:SetShown(unlocked)
    end
end

function ns.IsUnlocked() return unlocked end

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------
local core = CreateFrame("Frame")
core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("PLAYER_REGEN_DISABLED")
core:RegisterEvent("PLAYER_REGEN_ENABLED")
core:RegisterEvent("PLAYER_LOGOUT")
-- one-off troubleshooting notes some modules leave in the settings file;
-- only kept when "/keebui debug" is on
local NOTES = { "plateDump", "meterDump", "meterRowDump", "auraProbe", "targetAuraProbe", "plateSizeProbe",
    "targetPlateProbe", "oathProbe", "bgProbe", "blizzProbe", "setPanelHost",
    "dispelNote", "dispelNotes", "roleNote", "flagNote" }
core:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        if ns.db and not ns.db.debug then
            for _, key in ipairs(NOTES) do ns.db[key] = nil end
            ns.db.errors, ns.db.gameErrors = {}, nil
        end
    elseif event == "ADDON_LOADED" and arg1 == ADDON then
        -- settings saved before the welcome screen existed belong to someone
        -- already set up; a brand-new install starts with the welcome screen
        local existing = type(KeebUIDB) == "table" and next(KeebUIDB) ~= nil
        KeebUIDB = KeebUIDB or {}
        if KeebUIDB.setupDone == nil then KeebUIDB.setupDone = existing and true or false end
        for key, value in pairs(DEFAULTS) do
            if KeebUIDB[key] == nil then
                KeebUIDB[key] = type(value) == "table" and {} or value
            end
        end
        ns.db = KeebUIDB
        -- features that have been removed: drop their leftovers
        for _, key in ipairs({ "damageStrip", "stripOptIn", "meter", "meterRestored", "detailsWarned", "meterState",
            "meterStateCombat", "meterIconDump", "minimap", "minimapOut", "flight", "flights", "pally", "rested", "pallyPlaced", "restedPicked" }) do
            ns.db[key] = nil
        end
        if type(ns.db.fontFace) == "string" and ns.db.fontFace ~= "" then ns.FONT = ns.db.fontFace end
        ns.db.errors = {} -- only keep errors from the latest session
        ns.db.gameErrors = {}
    elseif event == "PLAYER_LOGIN" then
        if not ns.db.setupDone then
            -- first run: nothing is touched until you choose what you want
            if ns.ShowWelcome then C_Timer.After(1, ns.ShowWelcome) end
            return
        end
        for _, module in ipairs(ns.modules) do
            if ns.db[module.setting] then
                local ok, err = pcall(module.init)
                if not ok then ns.LogError("start " .. module.setting, err) end
            end
        end
        ns.PlaceAnchors()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if unlocked then ns.SetUnlocked(false) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        for frame, children in pairs(retireQueue) do
            retireQueue[frame] = nil
            ns.Retire(frame, children)
        end
    end
end)

---------------------------------------------------------------------------
-- Arcanite transmute alert. The transmute has a two-day cooldown, so the
-- moment it is ready is remembered (as a real-world time, per character) and
-- survives logging out. You are told once when it comes up while you are
-- playing, and once at each login for as long as it sits unused. Transmutes
-- waiting on your other characters are mentioned at login too.
---------------------------------------------------------------------------
local ARCANITE = 17187 -- Transmute: Arcanite

local function InitTransmute()
    ns.db.transmuteReady = type(ns.db.transmuteReady) == "table" and ns.db.transmuteReady or {}
    local store = ns.db.transmuteReady
    local me = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    local told = false -- already announced for this character this session

    -- seconds left on the cooldown; 0 when ready; nil when it cannot be read right now
    local function Remaining()
        local start, duration
        if C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(ARCANITE)
            if type(info) ~= "table" then return nil end
            start, duration = ns.Clean(info.startTime), ns.Clean(info.duration)
        elseif GetSpellCooldown then
            start, duration = GetSpellCooldown(ARCANITE)
            start, duration = ns.Clean(start), ns.Clean(duration)
        end
        if type(start) ~= "number" or type(duration) ~= "number" then return nil end
        if duration <= 2 then return 0 end -- nothing, or only the global cooldown
        return math.max(start + duration - GetTime(), 0)
    end

    local function Announce(text)
        ns.Print(text)
        if RaidNotice_AddMessage and RaidWarningFrame then
            pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.82, b = 0 })
        end
        if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound, SOUNDKIT.READY_CHECK, "Master") end
    end

    local function Check()
        local left = Remaining()
        if left == nil then return end
        if left > 0 then
            -- on cooldown: remember when it ends
            store[me] = { readyAt = GetServerTime() + left }
            told = false
        elseif store[me] and not told then
            -- this character has used it before, and it is ready now
            told = true
            store[me].readyAt = math.min(store[me].readyAt or 0, GetServerTime())
            Announce("Arcanite transmute is ready.")
        end
    end
    local SafeCheck = ns.Safe("transmute alert", Check)

    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, _, _, _, spellID)
        -- any spell could be another transmute sharing the cooldown; a quick look is cheap
        C_Timer.After(1, SafeCheck)
    end)
    C_Timer.NewTicker(30, SafeCheck)

    -- at login: this character (a few seconds in, once cooldowns are known), then the others
    C_Timer.After(6, function()
        SafeCheck()
        local now = GetServerTime()
        for who, entry in pairs(store) do
            if who ~= me and type(entry) == "table" and (entry.readyAt or 0) <= now then
                ns.Print("Arcanite transmute is ready on " .. who .. ".")
            end
        end
    end)
end

ns.modules[#ns.modules + 1] = { setting = "transmute", init = InitTransmute }
