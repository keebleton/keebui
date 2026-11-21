-- KeebUI unit frames: player, target, target of target, pet.

local ADDON, ns = ...
local Clean = ns.Clean

ns.FRAME_WIDTH = 240 -- player and target; the swing timer and cast bar match it
-- Centre height of the player and target frames above the screen bottom. The
-- bar stack tops out near 146; under the target frame sit a 6px gap, the 20px
-- enemy cast bar, then about 21px of air before the top row of buttons.
ns.FRAME_Y = 215
local POWER_HEIGHT = 12
local MANA_COLOR = { 0.27, 0.56, 1 } -- the game's own mana blue is very dark; this one reads at a glance
local AURA_SIZE, AURA_MAX = 22, 8
local frames = {}

---------------------------------------------------------------------------
-- Updates. Health and power go straight from the game into the bars.
---------------------------------------------------------------------------
local function HealthText(unit)
    if Clean(UnitIsConnected(unit)) == false then return "Offline" end
    if Clean(UnitIsDeadOrGhost(unit)) then return "Dead" end
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        return string.format("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    end
    local hp, max = Clean(UnitHealth(unit)), Clean(UnitHealthMax(unit))
    if hp and max and max > 0 then return string.format("%d%%", hp / max * 100) end
    return ""
end
ns.HealthText = HealthText

local function UpdateHealth(f)
    local unit = f.cuUnit
    f.health:SetMinMaxValues(0, UnitHealthMax(unit))
    f.health:SetValue(UnitHealth(unit))
    ns.UpdateHealPrediction(f.incoming, unit)
    if f.hpText then
        local text = HealthText(unit)
        -- while the mouse is over the frame, the percentage becomes exact numbers
        local alive = not Clean(UnitIsDeadOrGhost(unit)) and Clean(UnitIsConnected(unit)) ~= false
        if f.hovering and alive then
            text = string.format("%d / %d", UnitHealth(unit), UnitHealthMax(unit))
        end
        f.hpText:SetText(text)
    end
end

local function UpdatePower(f)
    if not f.power then return end
    local unit = f.cuUnit
    local powerType, token = UnitPowerType(unit)
    local kind, number = Clean(token), Clean(powerType)
    local c = PowerBarColor[kind or ""] or PowerBarColor[number or 0] or PowerBarColor.MANA
    if kind == "MANA" or (kind == nil and number == 0) then
        f.power:SetStatusBarColor(MANA_COLOR[1], MANA_COLOR[2], MANA_COLOR[3])
    else
        f.power:SetStatusBarColor(c.r, c.g, c.b)
    end
    f.power:SetMinMaxValues(0, UnitPowerMax(unit))
    f.power:SetValue(UnitPower(unit))
    if not f.powerText then return end
    if f.hovering then
        -- exact numbers while the mouse is over the frame
        f.powerText:SetText(string.format("%d / %d", UnitPower(unit), UnitPowerMax(unit)))
    elseif f.powerPercent then
        -- otherwise a percentage; nothing at all on a unit that has no power bar to speak of
        local max = Clean(UnitPowerMax(unit))
        local text = ""
        if max ~= 0 then
            local ok, made
            if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
                ok, made = pcall(function()
                    return string.format("%d%%", UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100))
                end)
            end
            if ok then
                text = made
            else
                local now = Clean(UnitPower(unit))
                if now and max and max > 0 then text = string.format("%d%%", now / max * 100) end
            end
        end
        f.powerText:SetText(text)
    else
        f.powerText:SetText("")
    end
end

local function UpdateIdentity(f)
    local unit = f.cuUnit
    f.name:SetText(UnitName(unit))
    f.health:SetStatusBarColor(ns.UnitColor(unit))

    if f.level then
        local level = Clean(UnitLevel(unit))
        local kind = Clean(UnitClassification(unit))
        local text = ""
        if level then
            text = level > 0 and tostring(level) or "??"
            if kind == "elite" or kind == "worldboss" then
                text = text .. "+"
            elseif kind == "rare" or kind == "rareelite" then
                text = text .. "r"
            end
            f.level:SetTextColor(ns.LevelColor(unit, level))
        end
        f.level:SetText(text)
    end

    if f.leader then
        f.leader:SetShown(IsInGroup() and Clean(UnitIsGroupLeader(unit)) and true or false)
    end

    if f.mark then
        local index = Clean(GetRaidTargetIndex(unit))
        if index then
            SetRaidTargetIconTexture(f.mark, index)
            f.mark:Show()
        else
            f.mark:Hide()
        end
    end
end

local function UpdateAuras(f)
    -- debuffs you can remove from yourself: icon on the bar, bar washed in the debuff's colour
    if f.removable and ns.UpdateRemovableDebuffs then ns.UpdateRemovableDebuffs(f.removable) end
    if not f.debuffs then return end
    local unit = f.cuUnit
    local shown = ns.FillAuras(f.debuffs, unit, "HARMFUL")
    ns.FillAuras(f.buffs, unit, "HELPFUL")
    -- buffs sit one row higher when there are debuffs under them
    f.buffs[1]:ClearAllPoints()
    f.buffs[1]:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, shown > 0 and (AURA_SIZE + 8) or 4)
end

local function UpdateCast(f)
    local bar = f.cast
    if not bar then return end
    local unit = f.cuUnit
    local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
    local duration
    local name, text, texture = UnitCastingInfo(unit)
    if name then
        duration = UnitCastingDuration and UnitCastingDuration(unit)
    else
        name, text, texture = UnitChannelInfo(unit)
        if name then
            duration = UnitChannelDuration and UnitChannelDuration(unit)
            direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
        end
    end
    if not name or not duration or not bar.SetTimerDuration then
        bar:Hide()
        return
    end
    local immediate = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    bar:SetTimerDuration(duration, immediate, direction)
    bar.icon:SetTexture(texture)
    bar.text:SetText(text)
    bar:Show()
end

local function UpdatePortrait(f)
    if not f.portrait2D then return end
    SetPortraitTexture(f.portrait2D, f.cuUnit)
end

-- Red glow around the player frame while in combat.
local function UpdateCombat(f)
    if not f.combat then return end
    f.combat:SetShown(Clean(UnitAffectingCombat("player")) and true or false)
end

local function UpdateAll(f)
    if not UnitExists(f.cuUnit) then return end
    UpdateCombat(f)
    UpdateIdentity(f)
    UpdatePortrait(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateAuras(f)
    UpdateCast(f)
    if f.auraContainers then
        -- The row right above the frame goes to whichever kind this target
        -- mostly has: debuffs on an enemy, buffs on a friend. The other kind
        -- takes the row above. (Otherwise a friend's buffs float over an
        -- empty debuff row.)
        local debuffs, buffs = f.auraContainers[1], f.auraContainers[2]
        local friendly = Clean(UnitIsFriend("player", f.cuUnit)) and true or false
        if f.auraFriendly ~= friendly and debuffs and buffs then
            local low, high = 4 + (f.auraLift or 0), 4 + (f.auraLift or 0) + AURA_SIZE + 4
            local ok = pcall(function()
                debuffs:ClearAllPoints()
                debuffs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, friendly and high or low)
                buffs:ClearAllPoints()
                buffs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, friendly and low or high)
            end)
            if ok then f.auraFriendly = friendly end
        end
        for _, container in ipairs(f.auraContainers) do
            pcall(container.UpdateAllAuras, container)
        end
    end
end

local HANDLERS = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateHealth,
    UNIT_HEAL_PREDICTION = UpdateHealth,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_POWER_FREQUENT = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_AURA = UpdateAuras,
    UNIT_NAME_UPDATE = UpdateIdentity,
    UNIT_LEVEL = UpdateIdentity,
    UNIT_FACTION = UpdateIdentity,
    UNIT_CLASSIFICATION_CHANGED = UpdateIdentity,
    RAID_TARGET_UPDATE = UpdateIdentity,
    -- the events themselves say which way it went; no need to ask again
    PLAYER_REGEN_DISABLED = function(f) if f.combat then f.combat:Show() end end,
    PLAYER_REGEN_ENABLED = function(f) if f.combat then f.combat:Hide() end end,
    UNIT_PORTRAIT_UPDATE = UpdatePortrait,
    UNIT_MODEL_CHANGED = UpdatePortrait,
    UNIT_SPELLCAST_START = UpdateCast,
    UNIT_SPELLCAST_STOP = UpdateCast,
    UNIT_SPELLCAST_FAILED = UpdateCast,
    UNIT_SPELLCAST_INTERRUPTED = UpdateCast,
    UNIT_SPELLCAST_DELAYED = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_START = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_UPDATE = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_STOP = UpdateCast,
}

local OnEvent = ns.Safe("unit frame", function(f, event)
    if not UnitExists(f.cuUnit) then return end
    local handler = HANDLERS[event] or UpdateAll
    handler(f)
end)

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function RegisterUnit(f, unit, events)
    for _, event in ipairs(events) do
        pcall(f.RegisterUnitEvent, f, event, unit)
    end
end

-- Debuffs and buffs above a frame, drawn by the game's own "aura container".
-- This client refuses to let addons read an enemy's auras ("cannot be
-- accessed when secret"), so the icons cannot be built here from aura data.
-- A container is the allowed route: we describe what to show and how each
-- icon should look, and the game fills it in itself.
local function AuraButton(button)
    -- every region is created and given a font before it is registered: the
    -- game writes into them the moment they are registered
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetReverse(true)
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end

    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    holder:EnableMouse(false)
    local stack = ns.Text(holder, 12, "RIGHT")
    stack:SetPoint("BOTTOMRIGHT", 1, 0)

    button:SetSize(AURA_SIZE, AURA_SIZE)
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetApplicationCount(stack, {})
    ns.AuraTooltip(button, cooldown)
end

local function AuraContainer(parent, filter)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetSize(1, 1) -- the game resizes it to fit its icons
    container:AddAuraGroup("all", filter, {
        maxFrameCount = AURA_MAX,
        initializeFrame = AuraButton,
        layout = { elementWidth = AURA_SIZE, elementHeight = AURA_SIZE, elementSpacing = 3, lineSpacing = 3 },
    })
    return container
end

local function AuraContainers(f, unit)
    if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    -- combo points, when they are shown on the target frame, take the strip
    -- right above it; the icon rows move up to make room
    local lift = (unit == "target" and ns.ComboPlace() == "target") and 11 or 0
    local debuffs = AuraContainer(f, "HARMFUL")
    debuffs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4 + lift)
    local buffs = AuraContainer(f, "HELPFUL")
    -- buffs sit one row above the debuffs
    buffs:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4 + lift + AURA_SIZE + 4)
    f.auraContainers = { debuffs, buffs }
    f.auraLift = lift
    -- the unit is set last: that is what makes the container start listening
    for _, container in ipairs(f.auraContainers) do
        container:SetUnit(unit)
        container:UpdateAllAuras()
    end
end

-- Our own icon rows, used only where containers are not available.
local function IconRows(f)
    f.debuffs, f.buffs = {}, {}
    for i = 1, AURA_MAX do
        local d = ns.AuraIcon(f, AURA_SIZE)
        if i == 1 then
            d:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
        else
            d:SetPoint("LEFT", f.debuffs[i - 1], "RIGHT", 3, 0)
        end
        f.debuffs[i] = d
        local b = ns.AuraIcon(f, AURA_SIZE)
        if i == 1 then
            b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
        else
            b:SetPoint("LEFT", f.buffs[i - 1], "RIGHT", 3, 0)
        end
        f.buffs[i] = b
    end
end

-- opts: power, level, auras, cast, textSize, poll (for units with no events)
local function Create(unit, label, width, height, x, y, opts)
    local anchor = ns.Anchor(unit, label, width, height, x, y)
    local f = CreateFrame("Button", "KeebUI_" .. unit, anchor, "SecureUnitButtonTemplate")
    f.cuUnit = unit
    f:SetAllPoints(anchor)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    ns.AttachMenu(f)
    local edge = ns.Edge(f)
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 1)

    -- square portrait on the outer side; the bars take the rest of the width
    local left, right = 0, 0
    local textInset = 0
    if opts.portrait then
        local holder = CreateFrame("Frame", nil, f)
        holder:SetSize(height, height)
        holder:SetPoint(opts.portrait)
        local back = holder:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0.07, 0.07, 0.07, 1)
        -- a static picture of the unit's face
        f.portrait2D = holder:CreateTexture(nil, "ARTWORK")
        f.portrait2D:SetAllPoints()
        f.portrait2D:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        if opts.portrait == "LEFT" then left = height + 1 else right = -(height + 1) end
    end

    f.health = ns.Bar(f)
    f.health:SetPoint("TOPLEFT", left, 0)
    f.health:SetPoint("TOPRIGHT", right, 0)
    if opts.power then
        f.power = ns.Bar(f)
        f.power:SetHeight(opts.powerHeight or POWER_HEIGHT)
        f.power:SetPoint("BOTTOMLEFT", left, 0)
        f.power:SetPoint("BOTTOMRIGHT", right, 0)
        f.health:SetPoint("BOTTOM", f.power, "TOP", 0, 1)
    else
        f.health:SetPoint("BOTTOM")
    end

    f.incoming = ns.HealPrediction(f.health)

    -- text and marks live on a layer above both bars
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints(f.health)
    top:SetFrameLevel(f.health:GetFrameLevel() + 3)
    local size = opts.textSize or 15

    local hover = top:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints(f)
    hover:SetColorTexture(1, 1, 1, 0.08)
    hover:Hide()
    if f.power then
        -- full-height power bars carry a percentage; the pet's thin one only shows numbers on hover
        f.powerPercent = not opts.powerHeight
        f.powerText = ns.Text(top, f.powerPercent and 11 or 13, "CENTER")
        f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
    end
    f:HookScript("OnEnter", function(self)
        f.hovering = true
        ns.Safe("health text", UpdateHealth)(f)
        ns.Safe("power text", UpdatePower)(f)
        hover:Show()
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        if pcall(GameTooltip.SetUnit, GameTooltip, unit) then GameTooltip:Show() end
    end)
    f:HookScript("OnLeave", function()
        f.hovering = false
        ns.Safe("health text", UpdateHealth)(f)
        ns.Safe("power text", UpdatePower)(f)
        hover:Hide()
        GameTooltip:Hide()
    end)

    if opts.hpText ~= false then
        f.hpText = ns.Text(top, size, "RIGHT")
        f.hpText:SetPoint("RIGHT", -5 - (opts.portrait == "RIGHT" and textInset or 0), 0)
    end
    if opts.level then
        f.level = ns.Text(top, size, "LEFT")
        f.level:SetPoint("LEFT", 5 + (opts.portrait == "LEFT" and textInset or 0), 0)
    end
    f.name = ns.Text(top, size, "LEFT")
    if f.level then
        f.name:SetPoint("LEFT", f.level, "RIGHT", 4, 0)
    else
        f.name:SetPoint("LEFT", 5 + (opts.portrait == "LEFT" and textInset or 0), 0)
    end
    if f.hpText then
        f.name:SetPoint("RIGHT", f.hpText, "LEFT", -4, 0)
    else
        f.name:SetPoint("RIGHT", -5, 0)
    end

    if opts.auras then
        f.mark = top:CreateTexture(nil, "OVERLAY")
        f.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        f.mark:SetSize(18, 18)
        f.mark:SetPoint("CENTER", f, "TOP", 0, 0)
        f.mark:Hide()

        local ok, err = pcall(AuraContainers, f, unit)
        if not ok then
            -- the game's containers are not available: fall back to our own rows
            ns.LogError("aura containers", err)
            f.auraContainers = nil
            IconRows(f)
        end
    end

    if opts.cast then
        local bar = ns.Bar(f)
        ns.Edge(bar)
        bar:SetHeight(20)
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 21, -6)
        bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -6)
        bar:SetStatusBarColor(0.85, 0.72, 0.3)
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetSize(20, 20)
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -1, 0)
        bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        bar.text = ns.Text(bar, 14, "LEFT")
        bar.text:SetPoint("LEFT", 4, 0)
        bar.text:SetPoint("RIGHT", -4, 0)
        bar:Hide()
        f.cast = bar
    end

    -- events
    RegisterUnit(f, unit, { "UNIT_HEAL_PREDICTION" })
    RegisterUnit(f, unit, { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_NAME_UPDATE",
        "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" })
    if opts.portrait then
        RegisterUnit(f, unit, { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" })
    end
    if opts.power then
        RegisterUnit(f, unit, { "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" })
    end
    if opts.auras then
        RegisterUnit(f, unit, { "UNIT_AURA" })
        f:RegisterEvent("RAID_TARGET_UPDATE")
    end
    if opts.cast then
        RegisterUnit(f, unit, { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" })
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    if unit == "target" then f:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if unit == "player" then
        -- debuffs you can remove from yourself, drawn by the game's aura
        -- container; our own version only if that is not available
        local ok, err = pcall(ns.RemovableOn, f, f.health, 26, "player")
        if not ok then
            ns.LogError("player aura container", err)
            if ns.MiddleSlots then
                f.removable = { unit = "player", middle = ns.MiddleSlots(top, 26) }
                RegisterUnit(f, unit, { "UNIT_AURA" })
            end
        end
    end
    if unit == "player" then
        -- a solid red rim with a wider, fainter one behind it; steady, no pulsing
        local glow = CreateFrame("Frame", nil, f)
        glow:SetFrameLevel(math.max(f:GetFrameLevel() - 1, 0))
        glow:SetPoint("TOPLEFT", (f.barLeft or 0) - 6, 6)
        glow:SetPoint("BOTTOMRIGHT", (f.barRight or 0) + 6, -6)
        local soft = glow:CreateTexture(nil, "BACKGROUND", nil, -8)
        soft:SetAllPoints()
        soft:SetColorTexture(0.9, 0.1, 0.1, 0.28)
        local mid = glow:CreateTexture(nil, "BACKGROUND", nil, -7)
        mid:SetPoint("TOPLEFT", 2, -2)
        mid:SetPoint("BOTTOMRIGHT", -2, 2)
        mid:SetColorTexture(0.9, 0.1, 0.1, 0.45)
        local rim = glow:CreateTexture(nil, "BACKGROUND", nil, -6)
        rim:SetPoint("TOPLEFT", 4, -4)
        rim:SetPoint("BOTTOMRIGHT", -4, 4)
        rim:SetColorTexture(0.95, 0.12, 0.12, 0.95)
        glow:Hide()
        f.combat = glow
        -- group leader crown on the frame's top-left corner (you are not in
        -- the party column, so this is where your own leadership shows)
        -- it rides on the portrait's ring, upper left, so the circle never covers it
        local crownOn = f.portraitHolder or top
        f.leader = crownOn:CreateTexture(nil, "OVERLAY", nil, 5)
        f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        f.leader:SetSize(16, 16)
        if f.portraitHolder then
            f.leader:SetPoint("CENTER", f.portraitHolder, "TOPLEFT", 7, -7)
        else
            f.leader:SetPoint("CENTER", f, "TOPLEFT", 3, -1)
        end
        f.leader:Hide()
        f:RegisterEvent("PARTY_LEADER_CHANGED")
        f:RegisterEvent("GROUP_ROSTER_UPDATE")
        f:RegisterEvent("PLAYER_LEVEL_UP") -- refresh the level shown on the frame
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    if unit == "pet" then f:RegisterUnitEvent("UNIT_PET", "player") end
    f:SetScript("OnEvent", OnEvent)
    f:HookScript("OnShow", ns.Safe("unit frame show", UpdateAll))

    if opts.poll then
        local elapsed = 0
        local refresh = ns.Safe("unit frame poll", UpdateAll)
        top:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.2 then return end
            elapsed = 0
            refresh(f)
        end)
    end

    RegisterUnitWatch(f)
    frames[unit] = f
    return f
end

---------------------------------------------------------------------------
-- Five-second rule. Spending mana on a spell stops your spirit-based mana
-- regeneration for five seconds. A thin, faint line sweeps across your mana
-- bar over those five seconds; when it reaches the end, regeneration is back.
--
-- Mana itself can be a hidden value in combat, so "did my mana go down" is
-- not something this can check. Instead it watches your own spells succeed
-- and asks the game what each one costs: a spell with a mana cost restarts
-- the five seconds, a free one does not.
---------------------------------------------------------------------------
local FIVE = 5

local function CostsMana(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellPowerCost) then return true end -- cannot tell: assume it does
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then return true end
    local mana = Enum.PowerType and Enum.PowerType.Mana or 0
    for _, cost in ipairs(costs) do
        local kind, amount = Clean(cost.type), Clean(cost.cost)
        if kind == mana and (amount == nil or amount > 0) then return true end
    end
    return false
end

local function InitFiveSecond(f)
    if not (f and f.power) or ns.db.fiveSecond == false then return end

    -- drawn on its own layer over the mana bar
    local layer = CreateFrame("Frame", nil, f.power)
    layer:SetAllPoints(f.power)
    layer:SetFrameLevel(f.power:GetFrameLevel() + 2)
    layer:Hide()
    local spark = layer:CreateTexture(nil, "OVERLAY")
    -- deliberately subtle: a single thin, half-bright line that stays inside
    -- the bar. No glow, no shading, nothing outside the mana bar.
    spark:SetColorTexture(1, 1, 1, 0.55)
    spark:SetSize(1, POWER_HEIGHT)

    local started
    layer:SetScript("OnUpdate", function(self)
        local progress = (GetTime() - started) / FIVE
        if progress >= 1 then
            self:Hide()
            return
        end
        local width = self:GetWidth()
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", self, "LEFT", width * progress, 0)
    end)

    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", ns.Safe("five-second rule", function(_, _, _, _, spellID)
        -- only while your bar is showing mana (not rage, energy or a form's resource)
        local powerType = Clean(UnitPowerType("player"))
        if powerType ~= (Enum.PowerType and Enum.PowerType.Mana or 0) then return end
        if not CostsMana(Clean(spellID)) then return end
        started = GetTime()
        layer:Show()
    end))
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
local function Init()
    -- x from screen centre, y from screen bottom: player and target flank the
    -- middle, just above the stacked action bars
    Create("player", "Player", ns.FRAME_WIDTH, 44, -250, ns.FRAME_Y, { power = true, level = true, portrait = "LEFT" })
    pcall(InitFiveSecond, _G.KeebUI_player)
    Create("target", "Target", ns.FRAME_WIDTH, 44, 250, ns.FRAME_Y,
        { power = true, level = true, auras = true, cast = true, portrait = "RIGHT" })
    Create("targettarget", "Target of target", 100, 22, 426, ns.FRAME_Y + 11, { hpText = false, textSize = 12, poll = true })
    -- the pet frame hangs under the player frame, below the swing timer: the same
    -- width as it, slim, with the pet's mana / focus / energy as a thin bar
    -- (on pet classes the swing timer is above the player frame, so the pet moves up into its place)
    -- Half the width of the player frame, lined up with its left edge.
    local PET_WIDTH = ns.FRAME_WIDTH / 2
    local petY = ns.PetClass() and (ns.FRAME_Y - 22 - 9 - 10.5) or (ns.FRAME_Y - 53)
    Create("pet", "Pet", PET_WIDTH, 21, -250 - (ns.FRAME_WIDTH - PET_WIDTH) / 2, petY,
        { textSize = 12, power = true, powerHeight = 4 })

    ns.Retire("PlayerFrame", { "healthbar", "manabar", "PlayerFrameHealthBar", "PlayerFrameManaBar" })
    ns.Retire("TargetFrame", { "healthbar", "manabar", "spellbar", "TargetFrameSpellBar", "totFrame", "TargetFrameToT" })
    ns.Retire("PetFrame", { "healthbar", "manabar" })
end

ns.modules[#ns.modules + 1] = { setting = "unitFrames", init = Init }

---------------------------------------------------------------------------
-- Blizzard's own unit frames (when "Unit frames" is set to Blizzard): left
-- exactly as the game draws them, except that their health bars take the
-- same colours KeebUI's frames use: class colour for players, and red /
-- yellow / green by attitude for everything else.
--
-- Only the colour of the bar is touched, and nothing is written onto the
-- game's frames, so their own code keeps running untouched.
---------------------------------------------------------------------------
local function InitBlizzard()
    if ns.db.unitFrames then return end -- KeebUI's own frames are in use

    local bars = {
        player = ns.BlizzBar("player", "healthbar"),
        target = ns.BlizzBar("target", "healthbar"),
        targettarget = ns.BlizzBar("targettarget", "healthbar"),
    }
    -- which of them were found, for troubleshooting
    ns.db.blizzProbe = {
        player = bars.player and true or false,
        target = bars.target and true or false,
        targettarget = bars.targettarget and true or false,
        mana = ns.BlizzBar("player", "manabar") and true or false,
    }

    local painting = false
    local function Paint(unit)
        local bar = bars[unit]
        if not bar or painting or not UnitExists(unit) then return end
        painting = true
        pcall(function()
            -- newer bar art is drawn already green; grey it first so the colour shows true
            local texture = bar:GetStatusBarTexture()
            if texture and texture.SetDesaturated then texture:SetDesaturated(true) end
            bar:SetStatusBarColor(ns.UnitColor(unit))
        end)
        painting = false
    end

    for unit, bar in pairs(bars) do
        -- whenever the game recolours the bar, put ours back
        hooksecurefunc(bar, "SetStatusBarColor", function() Paint(unit) end)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterUnitEvent("UNIT_FACTION", "player", "target")
    events:RegisterUnitEvent("UNIT_HEALTH", "player", "target")
    events:RegisterUnitEvent("UNIT_TARGET", "target")
    events:SetScript("OnEvent", ns.Safe("Blizzard frame colours", function()
        Paint("player")
        Paint("target")
        Paint("targettarget")
    end))

    -- the five-second-rule marker rides on Blizzard's mana bar instead
    local mana = ns.BlizzBar("player", "manabar")
    if mana then pcall(InitFiveSecond, { power = mana }) end
end

ns.modules[#ns.modules + 1] = { setting = "blizzClassColor", init = InitBlizzard }
