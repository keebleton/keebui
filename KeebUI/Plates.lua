-- KeebUI nameplates: the game's own nameplates, restyled in place.
-- The game keeps doing all the work (health, casts, who is shown), and other
-- addons that recolour the bars (ForeverThreatPlate) keep working. This only
-- changes the look: flat bar, thin black edge, readable name text, and a
-- white edge on your current target.

local ADDON, ns = ...
local Clean = ns.Clean

local extras = setmetatable({}, { __mode = "k" }) -- health bar -> textures we added
local NAME_SIZE = 14
local BAR_HEIGHT = 20 -- tall enough for the name and level to read clearly
-- how much black is laid over the bar colour (0 = full brightness)
local SHADE_TARGET, SHADE_OTHER, SHADE_IDLE = 0.12, 0.45, 0.28
local WIDTH = 0.75 -- share of the stock nameplate width the bar keeps
local ICON_GAP = 4 -- space between the bar and the debuff / crowd-control icons

local function HealthBar(frame)
    return frame.healthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
end

local function MarkTarget(frame, unit)
    local bar = HealthBar(frame)
    local added = bar and extras[bar]
    if not added then return end
    -- No bright outline at all: a light rim around a moving plate shimmers
    -- and is hard on the eyes. Every bar is toned down with a dark wash, and
    -- your target simply gets a much lighter wash, so it reads as the
    -- brightest plate on screen.
    local isTarget = unit and Clean(UnitIsUnit(unit, "target"))
    local wash = SHADE_IDLE
    if isTarget then
        wash = SHADE_TARGET
    elseif UnitExists("target") then
        wash = SHADE_OTHER
    end
    added.shade:SetColorTexture(0, 0, 0, wash)

    -- The target's whole plate is drawn larger, which would blow its debuff
    -- (DoT), buff and crowd-control icons up with it. They are scaled back
    -- down so they stay the size they are on every other plate.
    local auras = frame.AurasFrame
    if auras then
        local grow = tonumber(ns.db.targetPlateScale or 1.4) or 1.4
        local scale = isTarget and (1 / grow) or 1
        if added.iconScale ~= scale then
            added.iconScale = scale
            for _, key in ipairs({ "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame" }) do
                local list = auras[key]
                if list and list.SetScale then
                    local ok, err = pcall(list.SetScale, list, scale)
                    if not ok then ns.LogError("nameplate icon size", err) end
                end
            end
        end
    end
end

-- Enemy players get their class colour on the bar. (NPCs keep the game's
-- colour, or ForeverThreatPlate's threat colour.)
local function ClassColor(frame, unit)
    unit = unit or frame.unit
    if type(unit) ~= "string" or not unit:find("^nameplate") then return end
    -- only enemies; in a battleground the game will not say (the answer is
    -- hidden), and there the plates you see are the enemy team anyway
    local hostile = UnitCanAttack("player", unit)
    if not ns.IsSecret(hostile) and not hostile then return end
    local r, g, b = ns.ClassColorOf(unit)
    local bar = HealthBar(frame)
    if bar and (ns.IsSecret(r) or r) then bar:SetStatusBarColor(r, g, b) end
end

-- The game's own "class colour on enemy nameplates" setting, switched on as
-- well: where an addon is not allowed to read an enemy's class at all, the
-- game then colours the plate itself.
local function GameClassColor()
    if InCombatLockdown() then return end
    for _, name in ipairs({ "ShowClassColorInNameplate", "nameplateShowClassColor" }) do
        local ok, now = pcall(GetCVar, name)
        if ok and now ~= nil and tostring(now) ~= "1" then ns.SetCVar(name, "1") end
    end
end

---------------------------------------------------------------------------
-- Threat colours. While you are fighting a mob, its bar is coloured by where
-- you stand on its threat list. What each state means depends on your job:
--   tanking   : you WANT the mob on you  -> holding it is the calm colour
--   otherwise : you do NOT want it       -> having it is the alarm colour
-- Colours and the tank/damage choice are editable: /keebui threat
---------------------------------------------------------------------------
local THREAT_DEFAULTS = {
    mode = "auto", -- "auto", "tank" or "dps"
    tank = {
        secure = { 0.30, 0.55, 1.00 },   -- it is on you, firmly
        slipping = { 1.00, 0.85, 0.20 }, -- it is on you, but someone is catching up
        gaining = { 1.00, 0.55, 0.15 },  -- it is on someone else, you are close to taking it
        loose = { 0.90, 0.15, 0.15 },    -- it is on someone else
    },
    dps = {
        aggro = { 0.90, 0.15, 0.15 },    -- it is on you
        slipping = { 1.00, 0.45, 0.10 }, -- it is on you, the tank is close to taking it back
        high = { 1.00, 0.85, 0.20 },     -- you are close to pulling it
        safe = { 0.45, 0.50, 0.95 },     -- it is on someone else
    },
}
ns.THREAT_DEFAULTS = THREAT_DEFAULTS

-- what the game's four threat levels (0-3) are called in each mode
local THREAT_STATE = {
    tank = { [0] = "loose", [1] = "gaining", [2] = "slipping", [3] = "secure" },
    dps = { [0] = "safe", [1] = "high", [2] = "slipping", [3] = "aggro" },
}

local RIGHTEOUS_FURY, FORM_BEAR, FORM_DIRE_BEAR, FORM_DEFENSIVE = 25780, 5, 8, 18

local function ThreatSettings()
    local t = ns.db.threat
    if type(t) ~= "table" then
        t = {}
        ns.db.threat = t
    end
    t.mode = t.mode or THREAT_DEFAULTS.mode
    for _, mode in ipairs({ "tank", "dps" }) do
        t[mode] = t[mode] or {}
        for state, color in pairs(THREAT_DEFAULTS[mode]) do
            if type(t[mode][state]) ~= "table" then t[mode][state] = { color[1], color[2], color[3] } end
        end
    end
    return t
end

local function Tanking()
    local t = ThreatSettings()
    if t.mode == "tank" then return true end
    if t.mode == "dps" then return false end
    -- auto: no talent specs on this client, so go by stance / form / Righteous Fury
    local _, class = UnitClass("player")
    local form = GetShapeshiftFormID and Clean(GetShapeshiftFormID())
    if class == "WARRIOR" then return form == FORM_DEFENSIVE end
    if class == "DRUID" then return form == FORM_BEAR or form == FORM_DIRE_BEAR end
    if class == "PALADIN" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, RIGHTEOUS_FURY)
        return ok and aura ~= nil
    end
    return false
end
ns.IsTankingMode = Tanking
ns.ThreatSettings = ThreatSettings

local threatOwned = setmetatable({}, { __mode = "k" }) -- bars we have coloured
local gameColor = setmetatable({}, { __mode = "k" })   -- the colour the game last gave each bar

-- Colour one plate by threat. Returns true if it did.
local function ThreatColor(frame, unit)
    unit = unit or frame.unit
    local bar = HealthBar(frame)
    if not bar or type(unit) ~= "string" or not unit:find("^nameplate") then return end
    local status
    if ns.db.threatColors ~= false
        and Clean(UnitCanAttack("player", unit)) and not Clean(UnitIsPlayer(unit))
        and Clean(UnitAffectingCombat(unit)) then
        status = Clean(UnitThreatSituation("player", unit))
        -- Alone and not tanking, every mob you fight is on you by definition,
        -- so colouring them all "alarm" says nothing. Colours only apply when
        -- someone else could be holding it: in a group, or with a pet out.
        if status and not Tanking() and not (IsInGroup() or UnitExists("pet")) then status = nil end
    end
    if not status then
        -- not on its threat list: hand the bar back to the game's own colour
        if threatOwned[bar] then
            threatOwned[bar] = nil
            local c = gameColor[bar]
            if c then bar:SetStatusBarColor(c[1], c[2], c[3]) end
        end
        return
    end
    local mode = Tanking() and "tank" or "dps"
    local color = ThreatSettings()[mode][THREAT_STATE[mode][status] or ""]
    if not color then return end
    threatOwned[bar] = true
    bar:SetStatusBarColor(color[1], color[2], color[3])
    return true
end

local function ThreatAll()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local frame = plate.UnitFrame
        if frame and not (frame.IsForbidden and frame:IsForbidden()) then ThreatColor(frame, frame.unit) end
    end
end
ns.RefreshThreatColors = function() pcall(ThreatAll) end

-- Level text for inside the bar: "45", "45+" for elites, "??" for skulls,
-- coloured by how hard the mob is for you.
local function SetLevel(label, unit)
    local level = unit and Clean(UnitLevel(unit))
    if not level then
        label:SetText("")
        return
    end
    local kind = Clean(UnitClassification(unit))
    local text = level > 0 and tostring(level) or "??"
    if kind == "elite" or kind == "worldboss" or kind == "rareelite" then text = text .. "+" end
    label:SetTextColor(ns.LevelColor(unit, level))
    label:SetText(text)
end

-- The game's own level display (a box beside the bar on this client) is made
-- invisible, wherever it hangs: any part whose name mentions "level".
local function HideStockLevel(frame, bar)
    for _, owner in ipairs({ frame, bar, bar:GetParent() }) do
        if type(owner) == "table" then
            for key, part in pairs(owner) do
                if type(key) == "string" and key:lower():find("level", 1, true)
                    and type(part) == "table" and type(part.SetAlpha) == "function" then
                    pcall(part.SetAlpha, part, 0)
                end
            end
        end
    end
end

-- This client does not let addons read where a nameplate's parts are
-- anchored, only set it. So the icon rows are pinned to the bar outright, and
-- pinned again whenever the game moves them.
local pinned = setmetatable({}, { __mode = "k" })

-- The game moves these parts from inside its own protected code. Touching
-- them right there, in the middle of that code, makes the game treat its own
-- work as "interfered with by an addon" and raise errors. So the re-pin is
-- never done on the spot: it is queued and done a moment later, on our own time.
local function ApplyPin(part)
    local pin = pinned[part]
    if not pin or not pin.point then return end
    pin.queued = false
    pin.busy = true
    local ok, err = pcall(function()
        part:ClearAllPoints()
        part:SetPoint(pin.point, pin.bar, pin.relativePoint, pin.x, pin.y)
    end)
    pin.busy = false
    if not ok then ns.LogError("nameplate icons", err) end
end

local function Pin(part, point, bar, relativePoint, x, y)
    if not part or not part.SetPoint then return end
    local pin = pinned[part]
    if not pin then
        pin = {}
        pinned[part] = pin
        hooksecurefunc(part, "SetPoint", function()
            if pin.busy or pin.queued or not pin.point then return end
            pin.queued = true
            C_Timer.After(0, function() ApplyPin(part) end)
        end)
    end
    pin.point, pin.bar, pin.relativePoint, pin.x, pin.y = point, bar, relativePoint, x, y
    ApplyPin(part)
end

---------------------------------------------------------------------------
-- Quest marker: a small gold dot left of the bar on mobs you still need for
-- a quest.
---------------------------------------------------------------------------
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function Disc(parent, inset, r, g, b)
    local disc = parent:CreateTexture(nil, "ARTWORK", nil, inset > 0 and 1 or 0)
    disc:SetColorTexture(r, g, b, 1)
    disc:SetPoint("TOPLEFT", inset, -inset)
    disc:SetPoint("BOTTOMRIGHT", -inset, inset)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(disc)
    disc:AddMaskTexture(mask)
    return disc
end

local function CreateQuestDot(bar)
    local dot = CreateFrame("Frame", nil, bar)
    dot:SetSize(13, 13)
    dot:SetPoint("RIGHT", bar, "LEFT", -5, 0)
    Disc(dot, 0, 0, 0, 0)          -- dark rim
    Disc(dot, 2, 1, 0.8, 0.1)      -- gold centre
    dot:Hide()
    return dot
end

-- Is this unit one you still need for a quest in your log?
local function IsQuestUnit(unit)
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and Clean(related) then return true end
    end
    -- fall back to what the unit's tooltip says: an unfinished quest objective line
    local kinds = Enum.TooltipDataLineType
    if C_TooltipInfo and C_TooltipInfo.GetUnit and kinds and kinds.QuestObjective then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                if Clean(line.type) == kinds.QuestObjective and not Clean(line.completed) then
                    return true
                end
            end
        end
    end
    return false
end

local function UpdateQuestDot(frame, unit)
    local bar = HealthBar(frame)
    local added = bar and extras[bar]
    if not added or not added.quest then return end
    local show = false
    if unit and UnitExists(unit) and Clean(UnitCanAttack("player", unit)) and not Clean(UnitIsPlayer(unit)) then
        show = IsQuestUnit(unit)
    end
    -- when the elite / rare dragon is there, the dot steps out past it
    local kind = unit and Clean(UnitClassification(unit))
    local marked = kind == "elite" or kind == "rare" or kind == "rareelite" or kind == "worldboss"
    added.quest:ClearAllPoints()
    added.quest:SetPoint("RIGHT", bar, "LEFT", marked and -(ICON_GAP + 19 + 3) or -5, 0)
    added.quest:SetShown(show)
end

---------------------------------------------------------------------------
-- Cast bar: our own flat one under the health bar, exactly as wide as it,
-- in the same style as the target frame's. The game's rounded one is hidden.
---------------------------------------------------------------------------
local CAST_HEIGHT = 14

local function CreateCast(bar)
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -3)
    holder:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -3)
    holder:SetHeight(CAST_HEIGHT)
    holder:Hide()
    ns.Edge(holder)

    holder.icon = holder:CreateTexture(nil, "ARTWORK")
    holder.icon:SetSize(CAST_HEIGHT, CAST_HEIGHT)
    holder.icon:SetPoint("LEFT")
    holder.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local fill = ns.Bar(holder)
    fill:SetPoint("TOPLEFT", CAST_HEIGHT + 1, 0)
    fill:SetPoint("BOTTOMRIGHT")
    fill:SetStatusBarColor(0.85, 0.72, 0.3)
    holder.fill = fill

    holder.text = ns.Text(fill, 12, "LEFT")
    holder.text:SetPoint("LEFT", 3, 0)
    holder.text:SetPoint("RIGHT", -3, 0)
    return holder
end

local function UpdateCast(frame, unit)
    local bar = HealthBar(frame)
    local added = bar and extras[bar]
    local cast = added and added.cast
    if not cast then return end
    if not unit or not UnitExists(unit) then
        cast:Hide()
        return
    end
    local timer = Enum.StatusBarTimerDirection
    local direction = timer and timer.ElapsedTime
    local duration
    local name, text, texture = UnitCastingInfo(unit)
    if name then
        duration = UnitCastingDuration and UnitCastingDuration(unit)
    else
        name, text, texture = UnitChannelInfo(unit)
        if name then
            duration = UnitChannelDuration and UnitChannelDuration(unit)
            direction = timer and timer.RemainingTime
        end
    end
    if not name or not duration or not cast.fill.SetTimerDuration then
        cast:Hide()
        return
    end
    local immediate = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    cast.fill:SetTimerDuration(duration, immediate, direction)
    cast.icon:SetTexture(texture)
    cast.text:SetText(text)
    cast:Show()
end

local function Style(frame, unit)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    local bar = HealthBar(frame)
    if bar then
        bar:SetStatusBarTexture(ns.FLAT)
        -- narrower: pull both ends of the bar in from the space the game gives it
        local parent = bar:GetParent()
        local width = parent and parent ~= frame and Clean(parent:GetWidth())
        if width and width > 0 then
            local inset = width * (1 - WIDTH) / 2
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, 0)
            bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, 0)
            parent:SetHeight(BAR_HEIGHT)
        end
        -- debuffs sit just above the bar from its left edge; crowd control
        -- sits right beside the bar's right end
        local auras = frame.AurasFrame
        if auras then
            Pin(auras.DebuffListFrame, "BOTTOMLEFT", bar, "TOPLEFT", 0, ICON_GAP)
            Pin(auras.CrowdControlListFrame, "LEFT", bar, "RIGHT", ICON_GAP, 0)
        end
        -- the elite / rare dragon sits right against the bar's left end
        Pin(frame.ClassificationFrame, "RIGHT", bar, "LEFT", -ICON_GAP, 0)
        local added = extras[bar]
        if not added then
            added = {}
            extras[bar] = added
            added.edge = ns.Edge(bar)
            added.back = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
            added.back:SetAllPoints()
            added.back:SetColorTexture(0.07, 0.07, 0.07, 0.85)
            added.shade = bar:CreateTexture(nil, "OVERLAY", nil, -8)
            added.shade:SetAllPoints()
            added.shade:SetColorTexture(0, 0, 0, SHADE_IDLE)
        end
        -- the stock frame art around the bar
        for _, key in ipairs({ "border", "Border", "background", "bg", "bgTexture", "selectedBorder",
            "deselectedOverlay" }) do
            local art = bar[key]
            if art and art.SetAlpha then art:SetAlpha(0) end
        end
    end

    -- The name is drawn inside the bar. The game's own name label stays (it
    -- is what the game updates); ours copies its text and the original is
    -- made invisible while the bar is showing. On a plate with no bar
    -- (name-only), the original shows as normal.
    local name = frame.name
    if name and name.SetFont then
        ns.SetFont(name, 14)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        if bar then
            local added = extras[bar]
            if not added.name then
                local top = CreateFrame("Frame", nil, bar)
                top:SetAllPoints()
                top:SetFrameLevel(bar:GetFrameLevel() + 2)
                -- level on the right, name filling the rest from the left
                added.level = ns.Text(top, NAME_SIZE, "RIGHT")
                added.level:SetPoint("RIGHT", -4, 0)
                added.name = ns.Text(top, NAME_SIZE, "LEFT")
                added.name:SetPoint("LEFT", 4, 0)
                added.name:SetPoint("RIGHT", added.level, "LEFT", -3, 0)
                hooksecurefunc(name, "SetText", function(_, text) added.name:SetText(text) end)
            end
            added.name:SetText(name:GetText())
            name:SetAlpha(bar:IsShown() and 0 or 1)
            SetLevel(added.level, unit)
            HideStockLevel(frame, bar)
        end
    end

    if bar then
        local added = extras[bar]
        if not added.cast then added.cast = CreateCast(bar) end
        if not added.quest then added.quest = CreateQuestDot(bar) end
        UpdateQuestDot(frame, unit)
        if frame.CastBarsContainer then frame.CastBarsContainer:SetAlpha(0) end
        UpdateCast(frame, unit)
    end

    MarkTarget(frame, unit)
    ClassColor(frame, unit)
end

---------------------------------------------------------------------------
-- One-time snapshot of how this client builds a nameplate, saved with the
-- settings. It lets the styling above be tightened to the exact parts later.
---------------------------------------------------------------------------
local SNAPSHOT = 2

local function Describe(object)
    local out = {}
    for key, value in pairs(object) do
        if type(key) == "string" and type(value) == "table" and type(value.GetObjectType) == "function" then
            local ok, kind = pcall(value.GetObjectType, value)
            local note = ok and tostring(kind) or "?"
            if value.GetAtlas then
                local okAtlas, atlas = pcall(value.GetAtlas, value)
                if okAtlas and atlas then note = note .. " atlas=" .. tostring(atlas) end
            end
            if value.GetSize then
                local okSize, w, h = pcall(value.GetSize, value)
                if okSize and w then note = note .. (" %dx%d"):format(w, h) end
            end
            out[key] = note
        end
    end
    return out
end

local function Regions(frame)
    local out = {}
    for i, region in ipairs({ frame:GetRegions() }) do
        local note = region:GetObjectType() .. " layer=" .. tostring(region:GetDrawLayer())
        if region.GetAtlas and region:GetAtlas() then note = note .. " atlas=" .. tostring(region:GetAtlas()) end
        out[i] = note
    end
    return out
end

local function Snapshot(frame)
    if ns.db.plateSnapshot == SNAPSHOT then return end
    ns.db.plateSnapshot = SNAPSHOT
    local dump = { frame = Describe(frame), frameRegions = Regions(frame) }
    local bar = HealthBar(frame)
    if bar then
        dump.bar = Describe(bar)
        dump.barRegions = Regions(bar)
        local parent = bar:GetParent()
        if parent and parent ~= frame then
            dump.barParent = Describe(parent)
            dump.barParentRegions = Regions(parent)
        end
    end
    local cast = frame.castBar or frame.CastBar
    if cast then
        dump.cast = Describe(cast)
        dump.castRegions = Regions(cast)
    end
    -- where each part hangs: its anchors, and what they are attached to
    local names = { [frame] = "frame" }
    for key, value in pairs(frame) do
        if type(key) == "string" and type(value) == "table" and not names[value] then names[value] = key end
    end
    local function Anchors(part)
        local out = {}
        for i = 1, part:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = part:GetPoint(i)
            out[i] = ("%s -> %s %s %s,%s"):format(tostring(point),
                names[relativeTo] or (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "?",
                tostring(relativePoint), tostring(x), tostring(y))
        end
        return out
    end
    dump.anchors = {}
    for _, key in ipairs({ "HealthBarsContainer", "healthBar", "AurasFrame", "CastBarsContainer", "castBar",
        "name", "LevelFrame", "PlayerLevelDiffFrame", "ClassificationFrame", "RaidTargetFrame" }) do
        local part = frame[key]
        if part and part.GetNumPoints then
            local ok, result = pcall(Anchors, part)
            dump.anchors[key] = ok and result or tostring(result)
        end
    end
    local auras = frame.AurasFrame
    if auras then
        dump.auras = Describe(auras)
        dump.auraAnchors = {}
        for key, value in pairs(auras) do
            if type(key) == "string" and type(value) == "table" and value.GetNumPoints then
                names[value] = names[value] or ("AurasFrame." .. key)
                local ok, result = pcall(Anchors, value)
                dump.auraAnchors[key] = ok and result or tostring(result)
            end
        end
    end
    ns.db.plateDump = dump
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
local threatActive = false

local function Init()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end

    -- The game's own nameplate size setting (1 to 5). KeebUI's look is built
    -- around size 3, so that is applied at every login on every character.
    -- (It used to be set once per account, and on one account it never took.)
    do
        local want = tostring(ns.db.plateSize or 3)
        local function Apply()
            if InCombatLockdown() then return end
            pcall(GameClassColor)
            local now = GetCVar("nameplateSize")
            if tonumber(now or "") ~= tonumber(want) then
                local ok, err = ns.SetCVar("nameplateSize", want)
                ns.db.plateSizeProbe = { before = tostring(now), ok = ok, err = tostring(err),
                    after = tostring(GetCVar("nameplateSize")) }
            end
        end
        Apply()
        C_Timer.After(3, Apply)
    end

    local function StyleUnit(unit)
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        local frame = plate and plate.UnitFrame
        if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
        pcall(Snapshot, frame) -- before styling, so it records the game's own layout
        Style(frame, unit)
    end

    -- the game recolours bars now and then; put the class colour back right after
    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ns.Safe("nameplate class colour", function(frame)
            if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
            local bar = HealthBar(frame)
            if bar and type(frame.unit) == "string" and frame.unit:find("^nameplate") then
                local r, g, b = bar:GetStatusBarColor()
                r, g, b = Clean(r), Clean(g), Clean(b)
                if r and g and b then gameColor[bar] = { r, g, b } end
                threatOwned[bar] = nil
            end
            ClassColor(frame)
            if threatActive then ThreatColor(frame) end
        end))
    end

    -- Threat colours. ForeverThreatPlate does the same job; if it is running
    -- it keeps the job, so the two never fight over a bar's colour.
    threatActive = not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForeverThreatPlate"))
    if threatActive then
        local threat = CreateFrame("Frame")
        for _, event in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_REGEN_ENABLED",
            "PLAYER_REGEN_DISABLED", "UPDATE_SHAPESHIFT_FORM", "NAME_PLATE_UNIT_ADDED" }) do
            pcall(threat.RegisterEvent, threat, event)
        end
        threat:RegisterUnitEvent("UNIT_AURA", "player") -- Righteous Fury going on or off
        threat:SetScript("OnEvent", ns.Safe("nameplate threat", ThreatAll))
    end

    -- casts on any nameplate unit
    local casts = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        casts:RegisterEvent(event)
    end
    casts:SetScript("OnEvent", ns.Safe("nameplate cast", function(_, _, unit)
        if type(unit) ~= "string" or not unit:find("^nameplate") then return end
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        local frame = plate and plate.UnitFrame
        if frame and not (frame.IsForbidden and frame:IsForbidden()) then UpdateCast(frame, unit) end
    end))

    -- quest progress changes which mobs still matter; re-check the dots (once per burst)
    local quests = CreateFrame("Frame")
    quests:RegisterEvent("QUEST_LOG_UPDATE")
    local pending = false
    quests:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(0.3, ns.Safe("nameplate quest dots", function()
            pending = false
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                local frame = plate.UnitFrame
                if frame and not (frame.IsForbidden and frame:IsForbidden()) then
                    UpdateQuestDot(frame, frame.unit)
                end
            end
        end))
    end)

    -- Your target's nameplate is drawn larger than the rest. This is the
    -- game's own setting for it, so the game does the resizing.
    do
        local want = tostring(ns.db.targetPlateScale or 1.4)
        local function Apply()
            if InCombatLockdown() then return end
            local now = GetCVar("nameplateSelectedScale")
            if now ~= nil and tonumber(now) ~= tonumber(want) then ns.SetCVar("nameplateSelectedScale", want) end
            ns.db.targetPlateProbe = { before = tostring(now), after = tostring(GetCVar("nameplateSelectedScale")) }
        end
        Apply()
        C_Timer.After(3, Apply) -- once more after login settles
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:SetScript("OnEvent", ns.Safe("nameplates", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            StyleUnit(unit)
        else
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                local frame = plate.UnitFrame
                if frame and not (frame.IsForbidden and frame:IsForbidden()) then
                    MarkTarget(frame, frame.unit)
                end
            end
        end
    end))

    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local frame = plate.UnitFrame
        if frame and frame.unit and not (frame.IsForbidden and frame:IsForbidden()) then
            ns.Safe("nameplates", Style)(frame, frame.unit)
        end
    end
end

---------------------------------------------------------------------------
-- /keebui threat : pick the colours and the tank / damage mode
---------------------------------------------------------------------------
local ROWS = {
    { "tank", "When tanking" },
    { "tank", "secure", "Mob is on you" },
    { "tank", "slipping", "On you, but slipping" },
    { "tank", "gaining", "Not on you, nearly yours" },
    { "tank", "loose", "Mob is on someone else" },
    { "dps", "When not tanking" },
    { "dps", "aggro", "Mob is on you" },
    { "dps", "slipping", "On you, tank is taking it back" },
    { "dps", "high", "Close to pulling it" },
    { "dps", "safe", "Mob is on someone else" },
}
local MODES = { { "auto", "Auto" }, { "tank", "Tank" }, { "dps", "Damage / healer" } }
local threatWindow

local function PickColor(color, done)
    local old = { color[1], color[2], color[3] }
    local function apply(r, g, b)
        color[1], color[2], color[3] = r, g, b
        done()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1], g = color[2], b = color[3], hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() apply(old[1], old[2], old[3]) end,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = function() apply(ColorPickerFrame:GetColorRGB()) end
        ColorPickerFrame.cancelFunc = function() apply(old[1], old[2], old[3]) end
        ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
        ColorPickerFrame:Show()
    end
end

local function CreateThreatWindow()
    local f = CreateFrame("Frame", "KeebUIThreat", UIParent)
    f:SetSize(300, 60 + #ROWS * 24 + 70)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "KeebUIThreat")
    ns.Edge(f)
    local back = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    back:SetAllPoints()
    back:SetColorTexture(0.05, 0.05, 0.05, 0.94)

    local title = ns.Text(f, 16, "LEFT")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Nameplate threat colours")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local swatches = {}
    local function Paint()
        local t = ThreatSettings()
        for _, s in ipairs(swatches) do
            local c = t[s.mode][s.state]
            s.tex:SetColorTexture(c[1], c[2], c[3], 1)
        end
        for _, b in ipairs(f.modeButtons) do
            b.label:SetTextColor(t.mode == b.mode and 1 or 0.6, t.mode == b.mode and 0.82 or 0.6, t.mode == b.mode and 0 or 0.6)
        end
        f.now:SetText("Right now: " .. (Tanking() and "tanking" or "not tanking"))
        ns.RefreshThreatColors()
    end

    local y = -40
    for _, row in ipairs(ROWS) do
        if not row[3] then
            local head = ns.Text(f, 13, "LEFT")
            head:SetPoint("TOPLEFT", 12, y - 4)
            head:SetTextColor(0.6, 0.8, 1)
            head:SetText(row[2])
        else
            local mode, state = row[1], row[2]
            local b = CreateFrame("Button", nil, f)
            b:SetSize(270, 20)
            b:SetPoint("TOPLEFT", 20, y)
            local edge = b:CreateTexture(nil, "BACKGROUND")
            edge:SetColorTexture(0, 0, 0, 1)
            edge:SetSize(42, 16)
            edge:SetPoint("LEFT")
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
            local label = ns.Text(b, 13, "LEFT")
            label:SetPoint("LEFT", edge, "RIGHT", 8, 0)
            label:SetText(row[3])
            b:SetScript("OnClick", function() PickColor(ThreatSettings()[mode][state], Paint) end)
            swatches[#swatches + 1] = { mode = mode, state = state, tex = tex }
        end
        y = y - 24
    end

    -- mode
    y = y - 6
    local modeLabel = ns.Text(f, 13, "LEFT")
    modeLabel:SetPoint("TOPLEFT", 12, y)
    modeLabel:SetTextColor(0.6, 0.8, 1)
    modeLabel:SetText("I am:")
    f.modeButtons = {}
    local x = 56
    for _, def in ipairs(MODES) do
        local b = CreateFrame("Button", nil, f)
        b.mode = def[1]
        b.label = ns.Text(b, 13, "LEFT")
        b.label:SetPoint("LEFT")
        b.label:SetText(def[2])
        b:SetSize((b.label:GetStringWidth() or 40) + 6, 18)
        b:SetPoint("TOPLEFT", x, y + 2)
        b:SetScript("OnClick", function()
            ThreatSettings().mode = def[1]
            Paint()
        end)
        x = x + b:GetWidth() + 12
        f.modeButtons[#f.modeButtons + 1] = b
    end
    f.now = ns.Text(f, 12, "LEFT")
    f.now:SetPoint("TOPLEFT", 12, y - 22)
    f.now:SetTextColor(0.7, 0.7, 0.7)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(110, 22)
    reset:SetPoint("BOTTOMRIGHT", -10, 10)
    reset:SetText("Default colours")
    reset:SetScript("OnClick", function()
        ns.db.threat = nil
        Paint()
    end)

    f:SetScript("OnShow", Paint)
    return f
end

function ns.ToggleThreatWindow()
    threatWindow = threatWindow or CreateThreatWindow()
    threatWindow:SetShown(not threatWindow:IsShown())
end

ns.modules[#ns.modules + 1] = { setting = "plates", init = Init }
