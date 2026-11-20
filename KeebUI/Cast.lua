-- KeebUI cast bar and swing timer. These were the separate CleanCast and
-- CleanSwing addons; they now live here so they share the frames' look and
-- sit in fixed spots: the cast bar between the player and target frames, the
-- swing timer directly under the player frame at the same width.

local ADDON, ns = ...

local CAST_HEIGHT, CAST_FONT = 24, 16
local SWING_HEIGHT, SWING_GAP = 6, 3
local SWING_DROP = 10 -- below the player frame: clear of the 6px red combat glow around it
-- (the pet frame, on classes that have one, sits below the swing timer)
local FAIL_COLOR = { 0.85, 0.2, 0.2 }
local DONE_FADE, FAIL_FADE = 0.25, 0.6

local function ClassColor(shade)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    local r, g, b = c and c.r or 0.9, c and c.g or 0.9, c and c.b or 0.9
    return r * shade, g * shade, b * shade
end

-- Switch off a standalone addon this module replaces, now and for next login.
local function Replace(addon, anchorName)
    local anchor = _G[anchorName]
    if anchor then
        anchor:UnregisterAllEvents()
        anchor:Hide()
    end
    if C_AddOns and C_AddOns.DisableAddOn then pcall(C_AddOns.DisableAddOn, addon) end
end

---------------------------------------------------------------------------
-- Cast bar
---------------------------------------------------------------------------
local function InitCast()
    Replace("CleanCast", "CleanCastAnchor")

    local width = ns.FRAME_WIDTH or 240
    local anchor = ns.Anchor("cast", "Cast bar", width, CAST_HEIGHT, 0, ns.FRAME_Y or 221)

    local bar = ns.Bar(anchor)
    ns.Edge(bar)
    bar:SetPoint("TOPLEFT", CAST_HEIGHT + 1, 0) -- room for the spell icon
    bar:SetPoint("BOTTOMRIGHT")
    bar:Hide()

    local iconEdge = bar:CreateTexture(nil, "BACKGROUND")
    iconEdge:SetColorTexture(0, 0, 0, 1)
    iconEdge:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    iconEdge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", CAST_HEIGHT + 1, -1)
    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    icon:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", CAST_HEIGHT, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(1, 1, 1, 0.9)
    spark:SetSize(1, CAST_HEIGHT)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)

    local time = ns.Text(bar, CAST_FONT, "RIGHT")
    time:SetPoint("RIGHT", -4, 0)
    local name = ns.Text(bar, CAST_FONT, "LEFT")
    name:SetPoint("LEFT", 4, 0)
    name:SetPoint("RIGHT", time, "LEFT", -4, 0)

    local mode, castID, startTime, endTime, fadeStart, fadeTime

    -- mode is "cast" (fills up) or "channel" (drains); times are in seconds
    local function Begin(newMode, label, texture, startAt, endAt, id)
        mode, castID, startTime, endTime, fadeStart = newMode, id, startAt, endAt, nil
        bar:SetAlpha(1)
        bar:SetStatusBarColor(ClassColor(0.75))
        bar:SetMinMaxValues(0, math.max(endAt - startAt, 0.01))
        name:SetText(label or "")
        icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        spark:Show()
        bar:Show()
    end

    local function Fade(duration, failText)
        local _, max = bar:GetMinMaxValues()
        if failText then
            bar:SetStatusBarColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3])
            name:SetText(failText)
            bar:SetValue(max)
        elseif mode == "cast" then
            bar:SetValue(max)
        end
        mode = nil
        time:SetText("")
        spark:Hide()
        fadeStart, fadeTime = GetTime(), duration
    end

    -- Some internal spells are literally named "Opening - No Text".
    local function Label(spell, text)
        local label = (text and text ~= "") and text or spell or ""
        return (label:gsub("%s*%-%s*No Text$", ""))
    end

    local function ReadCast()
        local spell, text, texture, startMS, endMS, _, id = UnitCastingInfo("player")
        if spell and startMS and endMS then
            Begin("cast", Label(spell, text), texture, startMS / 1000, endMS / 1000, id)
            return true
        end
    end

    local function ReadChannel()
        local spell, text, texture, startMS, endMS = UnitChannelInfo("player")
        if spell and startMS and endMS then
            Begin("channel", Label(spell, text), texture, startMS / 1000, endMS / 1000)
            return true
        end
    end

    bar:SetScript("OnUpdate", ns.Safe("cast bar", function(self)
        local now = GetTime()
        if fadeStart then
            local progress = (now - fadeStart) / fadeTime
            if progress >= 1 then
                fadeStart = nil
                self:Hide()
            else
                self:SetAlpha(1 - progress)
            end
            return
        end
        if not mode then return end
        local remaining = endTime - now
        if remaining <= 0 then
            Fade(DONE_FADE) -- the stop event normally arrives first; this is the safety net
            return
        end
        self:SetValue(mode == "cast" and (now - startTime) or remaining)
        time:SetFormattedText("%.1f", remaining)
    end))

    local function HideNative()
        local native = PlayerCastingBarFrame or CastingBarFrame
        if not native then return end
        if native.SetUnit then
            native:SetUnit(nil)
        elseif CastingBarFrame_SetUnit then
            CastingBarFrame_SetUnit(native, nil)
        else
            native:UnregisterAllEvents()
        end
        native:Hide()
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:SetScript("OnEvent", ns.Safe("cast event", function(_, event, _, id)
        if event == "UNIT_SPELLCAST_START" then
            ReadCast()
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            ReadChannel()
        elseif event == "UNIT_SPELLCAST_DELAYED" then
            if mode == "cast" then ReadCast() end
        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            if mode == "channel" then ReadChannel() end
        elseif event == "UNIT_SPELLCAST_STOP" then
            if mode == "cast" and id == castID then Fade(DONE_FADE) end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            if mode == "channel" then Fade(DONE_FADE) end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            -- only for the cast on the bar, not some other spell that failed to start
            if id and id == castID and bar:IsShown() then
                Fade(FAIL_FADE, event == "UNIT_SPELLCAST_INTERRUPTED" and "Interrupted" or "Failed")
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            HideNative()
            if not (ReadCast() or ReadChannel()) then
                mode, fadeStart = nil, nil
                bar:Hide()
            end
        end
    end))
    HideNative()
end

---------------------------------------------------------------------------
-- Swing timer (the Forever client reports swings itself: PLAYER_SWING)
---------------------------------------------------------------------------
local MAIN_HAND, OFF_HAND, RANGED = 0, 1, 2

local function InitSwing()
    Replace("CleanSwing", "CleanSwingAnchor")

    local width = ns.FRAME_WIDTH or 240
    local holder
    local above = false -- true when the bars stack upward from above the player frame
    local player = _G.KeebUI_player
    if player then
        -- glued under the player frame: it moves and scales with it
        holder = CreateFrame("Frame", nil, player)
        if ns.PetClass() then
            -- pet classes: above the player frame (clear of its combat glow),
            -- leaving the space underneath for the pet frame
            above = true
            holder:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, SWING_DROP)
            holder:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, SWING_DROP)
        else
            -- combo points under the player frame take the first strip; the swing timer steps down
            local drop = SWING_DROP + (ns.ComboPlace() == "player" and 11 or 0)
            holder:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -drop)
            holder:SetPoint("TOPRIGHT", player, "BOTTOMRIGHT", 0, -drop)
        end
        holder:SetHeight(SWING_HEIGHT)
    else
        -- Blizzard's player frame: tucked under its mana bar, the same width,
        -- so it moves with the frame when you place that in Edit Mode. Pet
        -- classes have the pet frame there, so they get a free-standing,
        -- movable timer instead (as does anyone whose frame cannot be found).
        local mana = not ns.PetClass() and ns.BlizzBar and ns.BlizzBar("player", "manabar")
        if mana then
            local made = CreateFrame("Frame", nil, mana)
            local ok = pcall(function()
                made:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", 0, -7)
                made:SetPoint("TOPRIGHT", mana, "BOTTOMRIGHT", 0, -7)
                made:SetHeight(SWING_HEIGHT)
            end)
            if ok then holder = made else made:Hide() end
        end
        holder = holder or ns.Anchor("swing", "Swing timer", width, SWING_HEIGHT, -250, (ns.FRAME_Y or 221) - 28)
    end

    local bars = {}

    local function Restack()
        local row = 0
        for swingType = MAIN_HAND, RANGED do
            local bar = bars[swingType]
            if bar and bar:IsShown() then
                bar:ClearAllPoints()
                local step = row * (SWING_HEIGHT + SWING_GAP)
                bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, above and step or -step)
                bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, above and step or -step)
                row = row + 1
            end
        end
    end

    local function OnUpdate(self)
        local remaining = self.endTime - GetTime()
        if remaining <= 0 then
            self:Hide()
            return
        end
        self:SetValue(self.duration - remaining)
    end

    local function CreateBar(swingType)
        local bar = ns.Bar(holder)
        ns.Edge(bar)
        bar:SetHeight(SWING_HEIGHT)
        bar:SetStatusBarColor(ClassColor(swingType == OFF_HAND and 0.55 or 0.85))
        local spark = bar:CreateTexture(nil, "OVERLAY")
        spark:SetColorTexture(1, 1, 1, 0.9)
        spark:SetSize(1, SWING_HEIGHT)
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        bar:Hide()
        bar:SetScript("OnUpdate", OnUpdate)
        bar:SetScript("OnShow", Restack)
        bar:SetScript("OnHide", Restack)
        bars[swingType] = bar
        return bar
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_SWING")
    events:SetScript("OnEvent", ns.Safe("swing timer", function(_, _, duration, swingType)
        duration = ns.Clean(duration)
        swingType = ns.Clean(swingType) or MAIN_HAND
        if not duration or duration <= 0 then return end
        local bar = bars[swingType] or CreateBar(swingType)
        bar.duration = duration
        bar.endTime = GetTime() + duration
        bar:SetMinMaxValues(0, duration)
        bar:SetValue(0)
        bar:Show()
    end))

    -- The built-in swing setting stays on so the client keeps reporting swings;
    -- its own three bars are just made invisible.
    ns.SetCVar("showSwingTimer", "1")

    -- On a fresh character those bars may not exist yet at login, and the game
    -- can bring them back, so they are hidden whenever they turn up: now, a
    -- few times shortly after login, on every swing, and each time the game
    -- shows one.
    local hooked = {}
    local function HideNative()
        for _, name in ipairs({ "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame",
            "SwingTimerFrame", "SwingTimerContainer" }) do
            local native = _G[name]
            if native and native.SetAlpha then
                native:SetAlpha(0)
                if not hooked[native] then
                    hooked[native] = true
                    hooksecurefunc(native, "Show", function(self) self:SetAlpha(0) end)
                    if native.SetShown then
                        hooksecurefunc(native, "SetShown", function(self) self:SetAlpha(0) end)
                    end
                end
            end
        end
    end
    ns.HideNativeSwing = HideNative
    HideNative()
    for _, delay in ipairs({ 1, 3, 8 }) do C_Timer.After(delay, HideNative) end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_SWING")
    watcher:SetScript("OnEvent", HideNative)
end

---------------------------------------------------------------------------
-- Combo points (rogue, cat-form druid): five flat segments, gold, the fifth
-- red. Three placements, chosen in /keebui: on the target frame (default),
-- under your own frame, or centred above the action bars.
--
-- The count can be hidden from addons in combat, so it is never compared
-- here. Each segment is its own tiny bar that runs from (n-1) to n: handed
-- the count, the game fills it exactly when the count has reached n.
---------------------------------------------------------------------------
local COMBO_HEIGHT, COMBO_MAX = 7, 5

local function InitCombo()
    local place = ns.ComboPlace()
    if not place then return end

    local holder
    local target, player = _G.KeebUI_target, _G.KeebUI_player
    if place == "target" and target then
        holder = CreateFrame("Frame", nil, target)
        holder:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 4)
        holder:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 4)
        holder:SetHeight(COMBO_HEIGHT)
    elseif place == "player" and player then
        holder = CreateFrame("Frame", nil, player)
        holder:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -SWING_DROP)
        holder:SetPoint("TOPRIGHT", player, "BOTTOMRIGHT", 0, -SWING_DROP)
        holder:SetHeight(COMBO_HEIGHT)
    else
        -- above the bar stack (also the fallback if a frame is switched off); movable
        holder = ns.Anchor("combo", "Combo points", 170, COMBO_HEIGHT, 0, 156)
    end

    local segments = {}
    local gap = 3
    for i = 1, COMBO_MAX do
        local bar = ns.Bar(holder)
        ns.Edge(bar)
        bar:SetMinMaxValues(i - 1, i)
        bar:SetValue(0)
        if i == COMBO_MAX then
            bar:SetStatusBarColor(0.9, 0.28, 0.18)
        else
            bar:SetStatusBarColor(0.95, 0.76, 0.19)
        end
        segments[i] = bar
    end
    -- five equal segments across whatever width the holder ends up with
    local function Layout(width)
        if not width or width <= 0 then return end
        local each = (width - gap * (COMBO_MAX - 1)) / COMBO_MAX
        for i, bar in ipairs(segments) do
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (each + gap), 0)
            bar:SetSize(each, COMBO_HEIGHT)
        end
    end
    holder:SetScript("OnSizeChanged", function(_, width) Layout(width) end)
    Layout(holder:GetWidth())

    local function Update()
        -- druids only have combo points in cat form (energy)
        local _, class = UnitClass("player")
        local powerType = ns.Clean(UnitPowerType("player"))
        if class == "DRUID" and powerType ~= 3 then
            holder:SetAlpha(0)
            return
        end
        -- points live on the target on this client
        local points = GetComboPoints and GetComboPoints("player", "target") or 0
        for _, bar in ipairs(segments) do bar:SetValue(points) end
        local known = ns.Clean(points)
        -- nothing to show at zero; if the count is hidden, leave the row up
        holder:SetAlpha((known == 0 or not UnitExists("target")) and 0 or 1)
    end
    local SafeUpdate = ns.Safe("combo points", Update)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM" }) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    events:SetScript("OnEvent", SafeUpdate)
    SafeUpdate()
end

local function Init()
    InitCast()
    InitSwing()
    local ok, err = pcall(InitCombo)
    if not ok then ns.LogError("combo points", err) end
end

ns.modules[#ns.modules + 1] = { setting = "castSwing", init = Init }
