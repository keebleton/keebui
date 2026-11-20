-- KeebUI party and raid frames. The game's own group header creates and
-- assigns the buttons (so they keep working in combat); this file only
-- styles them and keeps them up to date.

local ADDON, ns = ...
local Clean = ns.Clean

---------------------------------------------------------------------------
-- Settings. Everything about how a cell is laid out and what it shows comes
-- from here; the window in GroupOptions.lua edits them. Only what you have
-- changed is saved, the rest falls through to these defaults.
--
-- Party: a column stacked upward from just above the player frame, the same
-- width as it. You are not repeated in it unless you ask to be.
-- Raid: a grid of groups, with a cell size for each of three raid sizes.
--
-- Where things go ("spots"): the eight edges and corners inside the cell,
-- or OUT_LEFT / OUT_RIGHT, beside the cell.
---------------------------------------------------------------------------
local DEFAULTS = {
    party = {
        width = 240, height = 32, text = 14, gap = 4, growUp = true, showPlayer = false,
        healthText = "percent", nameColor = "white", nameLength = 0, power = "none",
        dispelSize = 24, dispelTint = true, tintStrength = 0.5, stacks = true,
        debuffCount = 3, debuffSize = 20, debuffSpot = "OUT_RIGHT",
        buffCount = 4, buffSize = 20, buffSpot = "OUT_LEFT", buffMaxSeconds = 60,
        barColor = "class", rangeAlpha = 0.45, heals = true, aggro = true, castStrip = true,
    },
    raid = {
        w10 = 122, h10 = 44, t10 = 14, w20 = 96, h20 = 38, t20 = 13, w40 = 76, h40 = 34, t40 = 12,
        gap = 1, orientation = "COLUMNS", sort = "GROUP",
        healthText = "none", nameColor = "white", nameLength = 0, power = "none",
        dispelSize = 22, dispelTint = true, tintStrength = 0.5, stacks = true,
        debuffCount = 3, debuffSize = 14, debuffSpot = "BOTTOMLEFT",
        buffCount = 3, buffSize = 12, buffSpot = "TOPRIGHT", buffMaxSeconds = 60,
        barColor = "class", rangeAlpha = 0.45, heals = true, aggro = true, castStrip = true,
    },
}
ns.FRAME_DEFAULTS = DEFAULTS

local function CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

-- Is this character using its own frame settings instead of the shared ones?
function ns.FramesPerCharacter()
    return type(ns.db.framesOwn) == "table" and ns.db.framesOwn[CharKey()] and true or false
end

-- Switching it on starts this character off with a copy of the shared settings.
function ns.SetFramesPerCharacter(on)
    local db, key = ns.db, CharKey()
    db.framesOwn = type(db.framesOwn) == "table" and db.framesOwn or {}
    db.framesChar = type(db.framesChar) == "table" and db.framesChar or {}
    if on and not db.framesChar[key] then
        local copy = {}
        for kind, values in pairs(db.frames or {}) do
            copy[kind] = {}
            for k, v in pairs(values) do copy[kind][k] = v end
        end
        db.framesChar[key] = copy
    end
    db.framesOwn[key] = on and true or nil
end

-- The settings for "party" or "raid": yours where set, otherwise the defaults.
function ns.FrameSettings(kind)
    local db = ns.db
    local store
    if ns.FramesPerCharacter() then
        db.framesChar = type(db.framesChar) == "table" and db.framesChar or {}
        local key = CharKey()
        db.framesChar[key] = type(db.framesChar[key]) == "table" and db.framesChar[key] or {}
        store = db.framesChar[key]
    else
        db.frames = type(db.frames) == "table" and db.frames or {}
        store = db.frames
    end
    store[kind] = type(store[kind]) == "table" and store[kind] or {}
    return setmetatable(store[kind], { __index = DEFAULTS[kind] })
end

-- What a header and its cells are built from: the settings plus the sizes in force.
local function Config(kind)
    local S = ns.FrameSettings(kind)
    if kind == "party" then
        -- row: name on the left, health text on the right (raid cells stack them)
        return { kind = kind, S = S, row = true, debuffs = 3,
            width = S.width, height = S.height, text = S.text, gap = S.gap, growUp = S.growUp and true or false }
    end
    return { kind = kind, S = S, width = S.w40, height = S.h40, text = S.t40, gap = S.gap }
end

-- Where an icon row goes, by spot name.
local function PlaceAt(frame, button, health, spot)
    spot = spot or "BOTTOMLEFT"
    if spot == "OUT_LEFT" then
        frame:SetPoint("RIGHT", button, "LEFT", -4, 0)
    elseif spot == "OUT_RIGHT" then
        frame:SetPoint("LEFT", button, "RIGHT", 4, 0)
    else
        local x = spot:find("LEFT") and 2 or (spot:find("RIGHT") and -2 or 0)
        local y = spot:find("TOP") and -2 or (spot:find("BOTTOM") and 2 or 0)
        frame:SetPoint(spot, health, spot, x, y)
    end
end
ns.GroupPlaceAt = PlaceAt

local MANA_BLUE = { 0.27, 0.56, 1 }

local cells = setmetatable({}, { __mode = "k" }) -- button -> its visuals and state
local byUnit = {}                                -- "raid3" -> button

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------
local function Short(n)
    if n >= 10000 then return ("%.0fk"):format(n / 1000) end
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return ("%d"):format(n)
end

-- The text under / beside the name. In combat health numbers are hidden
-- values: they can be handed to the label, not looked at, so each mode has a
-- form that needs no arithmetic here.
local function HealthLabel(d, unit)
    local mode = d.cfg.S.healthText
    if mode == "percent" then
        return ns.HealthText(unit)
    elseif mode == "current" then
        local hp = UnitHealth(unit)
        if ns.IsSecret(hp) then return string.format("%d", hp) end
        return Short(hp or 0)
    elseif mode == "deficit" then
        if UnitHealthMissing then
            local missing = UnitHealthMissing(unit)
            if ns.IsSecret(missing) then
                -- the game's own "nothing when it is zero" formatter, where there is one
                if C_StringUtil and C_StringUtil.TruncateWhenZero then return C_StringUtil.TruncateWhenZero(missing) end
                return string.format("-%d", missing)
            end
            return (missing and missing > 0) and ("-" .. Short(missing)) or ""
        end
        local hp, max = Clean(UnitHealth(unit)), Clean(UnitHealthMax(unit))
        if hp and max and max > hp then return "-" .. Short(max - hp) end
    end
    return ""
end

-- green -> yellow -> red by health, worked out by the game from a colour curve
local healthCurve
local function HealthColor(unit)
    if healthCurve == nil then
        healthCurve = false
        if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(0.85, 0.18, 0.18, 1))
            curve:AddPoint(0.5, CreateColor(0.9, 0.75, 0.15, 1))
            curve:AddPoint(1, CreateColor(0.25, 0.72, 0.3, 1))
            healthCurve = curve
        end
    end
    if healthCurve and UnitHealthPercent then
        local ok, color = pcall(UnitHealthPercent, unit, true, healthCurve)
        if ok and type(color) == "table" and color.GetRGB then return color:GetRGB() end
    end
    local hp, max = Clean(UnitHealth(unit)), Clean(UnitHealthMax(unit))
    if hp and max and max > 0 then
        local f = math.max(0, math.min(1, hp / max))
        if f > 0.5 then
            local t = (f - 0.5) * 2
            return 0.9 + (0.25 - 0.9) * t, 0.75 + (0.72 - 0.75) * t, 0.15 + (0.3 - 0.15) * t
        end
        local t = f * 2
        return 0.85 + (0.9 - 0.85) * t, 0.18 + (0.75 - 0.18) * t, 0.18 + (0.15 - 0.18) * t
    end
end

-- The bar's colour for modes that do not change with health.
local function PaintBar(d, unit)
    local mode = d.cfg.S.barColor
    if mode == "dark" then
        d.health:SetStatusBarColor(0.2, 0.21, 0.2)
    elseif mode ~= "health" then
        d.health:SetStatusBarColor(ns.UnitColor(unit))
    end
end

local function UpdateHealth(d)
    local unit = d.unit
    d.health:SetMinMaxValues(0, UnitHealthMax(unit))
    d.health:SetValue(UnitHealth(unit))
    if d.cfg.S.heals ~= false then ns.UpdateHealPrediction(d.incoming, unit) end
    if d.cfg.S.barColor == "health" then
        local r, g, b = HealthColor(unit)
        if ns.IsSecret(r) or r then d.health:SetStatusBarColor(r, g, b) else d.health:SetStatusBarColor(ns.UnitColor(unit)) end
    end

    local offline = Clean(UnitIsConnected(unit)) == false
    local dead = Clean(UnitIsDeadOrGhost(unit))
    -- Raid cells stack the name over the health text. With no health text
    -- there is nothing underneath, so the name sits in the middle of the cell;
    -- it moves up again to make room for "Dead" or "Offline".
    if not d.cfg.row then
        local raised = (offline or dead or d.cfg.S.healthText ~= "none") and true or false
        if d.nameRaised ~= raised then
            d.nameRaised = raised
            local y = raised and 5 or 0
            pcall(function()
                d.name:ClearAllPoints()
                d.name:SetPoint("LEFT", 3, y)
                d.name:SetPoint("RIGHT", -3, y)
            end)
        end
    end
    if offline or dead then
        d.status:SetText(offline and "Offline" or "Dead")
        d.status:SetTextColor(0.8, 0.4, 0.4)
        d.name:SetTextColor(0.6, 0.6, 0.6)
    else
        local ok, text = pcall(HealthLabel, d, unit)
        d.status:SetText(ok and text or "")
        d.status:SetTextColor(1, 1, 1)
        if d.nameR ~= nil then
            d.name:SetTextColor(d.nameR, d.nameG, d.nameB)
        else
            d.name:SetTextColor(1, 1, 1)
        end
    end
end

-- A thin bar along the bottom of the cell for mana (or every power type).
local function UpdatePower(d)
    local bar = d.power
    if not bar then return end
    local unit = d.unit
    local powerType, token = UnitPowerType(unit)
    local kind, number = Clean(token), Clean(powerType)
    local mana = kind == "MANA" or (kind == nil and number == 0)
    if d.cfg.S.power == "mana" and not mana then
        bar:Hide()
        return
    end
    if mana then
        bar:SetStatusBarColor(MANA_BLUE[1], MANA_BLUE[2], MANA_BLUE[3])
    else
        local c = PowerBarColor[kind or ""] or PowerBarColor[number or 0] or PowerBarColor.MANA
        bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    bar:SetMinMaxValues(0, UnitPowerMax(unit))
    bar:SetValue(UnitPower(unit))
    bar:Show()
end

-- What each class can remove.
local CAN_DISPEL = {
    PALADIN = { Magic = true, Poison = true, Disease = true },
    PRIEST = { Magic = true, Disease = true },
    DRUID = { Curse = true, Poison = true },
    SHAMAN = { Poison = true, Disease = true },
    MAGE = { Curse = true },
}
local MINE = CAN_DISPEL[select(2, UnitClass("player"))] or {}
local TYPE_COLOR = {
    Magic = { 0.35, 0.47, 1 }, Curse = { 0.64, 0, 0.64 },
    Disease = { 0.67, 0.45, 0.1 }, Poison = { 0, 0.7, 0.29 },
}
local TYPE_INDEX = { [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison" }

-- Things that count as "debuffs" to the game but are not worth showing on a
-- group frame: the camp tent / campfire bonus-XP auras.
local IGNORE_ID = { [1229451] = true, [1325299] = true, -- Boosted Rest
    [1229741] = true, [1229432] = true, [1229517] = true, [1232234] = true }
local IGNORE_NAME = { ["Boosted Rest"] = true, ["Camp Benefits"] = true, ["Camp Tent"] = true,
    ["Camp Chair"] = true, ["Cozy Fire"] = true }
-- Once an aura has been recognised (when the game lets its name be read) it is
-- remembered by its instance number, which stays readable in combat.
local ignoredInstance = {}

local function Ignored(aura)
    local instance = aura.auraInstanceID
    if ns.IsSecret(instance) then return false end
    if ignoredInstance[instance] then return true end
    local id, name = Clean(aura.spellId), Clean(aura.name)
    if (id and IGNORE_ID[id]) or (name and IGNORE_NAME[name]) then
        ignoredInstance[instance] = true
        return true
    end
    return false
end

-- When the game hides a debuff's type from addons (it does in some combat),
-- these let the game itself decide what is visible: each maps a debuff type
-- to a colour whose alpha is 1 or 0, and the game applies it for us.
--   mineIcon : opaque for types you can remove, invisible otherwise
--   mineWash : the type's colour at half strength for types you can remove
--   otherIcon: the opposite of mineIcon
local mineIcon, mineWash, otherIcon

local function BuildCurves()
    if mineIcon then return end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType) then return end
    local function make(fn)
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        for index = 0, 12 do
            local kind = TYPE_INDEX[index]
            curve:AddPoint(index, CreateColor(fn(kind, kind and MINE[kind])))
        end
        return curve
    end
    mineIcon = make(function(_, mine) return 1, 1, 1, mine and 1 or 0 end)
    mineWash = make(function(kind, mine)
        local c = TYPE_COLOR[kind] or { 1, 1, 1 }
        return c[1], c[2], c[3], mine and 0.5 or 0
    end)
    otherIcon = make(function(_, mine) return 1, 1, 1, mine and 0 or 1 end)
end

local function CurveColor(unit, aura, curve)
    if not (curve and C_UnitAuras.GetAuraDispelTypeColor) then return end
    local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, aura.auraInstanceID, curve)
    if ok and color then return color end
end

-- Oath of Light (paladin talent on this client): a 5-minute buff you can keep
-- on one ally at a time. The member carrying yours gets its icon on their
-- cell, with a sweep showing the time left.
local OATH_ID = 1328548
local oathName
local oathInstance = {} -- unit -> the buff's instance number, once recognised

local function KnowsOath()
    return (IsPlayerSpell and IsPlayerSpell(OATH_ID)) or (IsSpellKnown and IsSpellKnown(OATH_ID)) or false
end

local function FindOath(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    -- already recognised on this unit: that stays checkable in combat, when
    -- the game may hide a buff's name and number
    local known = oathInstance[unit]
    if known and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, known)
        if ok and aura then return aura end
        oathInstance[unit] = nil
    end
    oathName = oathName or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(OATH_ID)) or "Oath of Light"
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL|PLAYER")
        if not ok or not aura then break end
        local id, name = Clean(aura.spellId), Clean(aura.name)
        if id == OATH_ID or (name and name == oathName) then
            local instance = aura.auraInstanceID
            if not ns.IsSecret(instance) then oathInstance[unit] = instance end
            return aura
        end
    end
end

local function UpdateOath(d)
    if not d.oath then return end
    local aura = KnowsOath() and FindOath(d.unit)
    if aura then
        ns.ShowAura(d.oath, d.unit, aura, false)
    else
        d.oath:Hide()
    end
end

-- Debuffs on a cell:
--   ones you can remove -> icon in the middle of the cell, cell washed in the debuff's colour
--   ones you cannot     -> small icons to the right of the cell (party only)
local function UpdateAuras(d)
    if d.containers then
        -- the game draws these itself (see CellContainers); only the size of
        -- the removable-debuff pictures is ours to keep right
        if d.dispelRefresh then d.dispelRefresh() end
        return
    end
    local unit = d.unit
    local middle, side = 0, 0
    local middleMax, sideMax = #d.middle, d.debuffs and #d.debuffs or 0

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 16 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not aura then break end
            if not Ignored(aura) then
                -- Only a type we can actually read as text is trusted. In combat
                -- the game may hand back nothing at all for the type (not even a
                -- hidden value), which must not be mistaken for "has no type".
                local kind = Clean(aura.dispelName)
                if type(kind) == "string" and kind ~= "" then
                    if MINE[kind] then
                        if middle < middleMax then
                            middle = middle + 1
                            local slot = d.middle[middle]
                            local c = TYPE_COLOR[kind]
                            slot.icon:SetTexture(aura.icon)
                            slot.icon:SetVertexColor(1, 1, 1, 1)
                            slot.edge:SetVertexColor(1, 1, 1, 1)
                            slot.wash:SetVertexColor(c[1], c[2], c[3], 0.5)
                            slot.icon:Show()
                            slot.edge:Show()
                            slot.wash:Show()
                        end
                    elseif side < sideMax then
                        side = side + 1
                        ns.ShowAura(d.debuffs[side], unit, aura, true)
                        d.debuffs[side]:SetAlpha(1)
                    end
                else
                    -- the type is hidden or missing: give it a place in both
                    -- spots and let the game make the wrong one invisible
                    local iconColor = CurveColor(unit, aura, mineIcon)
                    local washColor = CurveColor(unit, aura, mineWash)
                    local sideColor = CurveColor(unit, aura, otherIcon)
                    -- one-time note of what the game reported, saved with the
                    -- settings, in case this path needs another look
                    if unit == "player" and not ns.db.auraProbe then
                        local alpha = iconColor and select(4, iconColor:GetRGBA())
                        ns.db.auraProbe = {
                            type = ns.IsSecret(aura.dispelName) and "hidden" or tostring(aura.dispelName),
                            combat = InCombatLockdown() and true or false,
                            gotIcon = iconColor ~= nil,
                            gotWash = washColor ~= nil,
                            alpha = ns.IsSecret(alpha) and "hidden" or tostring(alpha),
                            name = ns.IsSecret(aura.name) and "hidden" or tostring(aura.name),
                        }
                    end
                    if iconColor and washColor and middle < middleMax then
                        middle = middle + 1
                        local slot = d.middle[middle]
                        slot.icon:SetTexture(aura.icon)
                        slot.icon:SetVertexColor(iconColor:GetRGBA())
                        slot.edge:SetVertexColor(iconColor:GetRGBA())
                        slot.wash:SetVertexColor(washColor:GetRGBA())
                        slot.icon:Show()
                        slot.edge:Show()
                        slot.wash:Show()
                    end
                    if side < sideMax then
                        side = side + 1
                        local icon = d.debuffs[side]
                        ns.ShowAura(icon, unit, aura, true)
                        if not (sideColor and pcall(icon.SetAlpha, icon, select(4, sideColor:GetRGBA()))) then
                            icon:SetAlpha(1)
                        end
                    end
                end
            end
        end
    end

    for i = middle + 1, middleMax do
        local slot = d.middle[i]
        slot.icon:Hide()
        slot.edge:Hide()
        slot.wash:Hide()
    end
    for i = side + 1, sideMax do d.debuffs[i]:Hide() end
    UpdateOath(d)
end

-- Removable-debuff slots for the middle of a bar: up to three, each a colour
-- wash over the whole bar plus the debuff's icon, in a row from the centre.
local function MiddleSlots(top, iconSize)
    local slots = {}
    for i = 1, 3 do
        local slot = {}
        slot.wash = top:CreateTexture(nil, "ARTWORK", nil, 1)
        slot.wash:SetAllPoints()
        slot.wash:SetColorTexture(1, 1, 1, 1)
        slot.wash:Hide()
        slot.edge = top:CreateTexture(nil, "OVERLAY", nil, 3)
        slot.edge:SetColorTexture(0, 0, 0, 1)
        slot.edge:SetSize(iconSize + 2, iconSize + 2)
        slot.edge:SetPoint("CENTER", (i - 1) * (iconSize + 4), 0)
        slot.edge:Hide()
        slot.icon = top:CreateTexture(nil, "OVERLAY", nil, 4)
        slot.icon:SetSize(iconSize, iconSize)
        slot.icon:SetPoint("CENTER", slot.edge, "CENTER")
        slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        slot.icon:Hide()
        slots[i] = slot
    end
    return slots
end

---------------------------------------------------------------------------
-- Aura containers. In combat this client stops letting addons read auras,
-- even on party members, so anything built from aura data goes blank or
-- stale mid-fight. The game's own containers do not have that limit: we say
-- what to show (a filter) and what it should look like, and the game shows
-- and hides it itself. Everything a cell shows about auras goes through
-- them; the code above remains only as a fallback where they are missing.
---------------------------------------------------------------------------
local function NewContainer(parent)
    if C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetSize(1, 1) -- the game resizes it to fit
    return container
end

-- A stack count on a container-owned button, where the game offers one.
local function StackCount(button, anchor, size)
    if not button.SetApplicationCount then return end
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(button:GetFrameLevel() + 3) -- above the time-left sweep
    local count = ns.Text(holder, size, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
    pcall(button.SetApplicationCount, button, count, {})
    return count
end

-- icon + black edge (+ optional time-left sweep, + optional stack count) on a container-owned button
local function DressButton(button, size, sweep, stacks)
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local cooldown
    if sweep then
        cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(button)
        cooldown:SetDrawEdge(false)
        cooldown:SetReverse(true)
        if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    end
    button:SetSize(size, size)
    button:SetIcon(icon)
    if cooldown then button:SetDurationCooldown(cooldown) end
    if stacks then StackCount(button, icon, math.max(9, math.floor(size * 0.6))) end
    ns.AuraTooltip(button, cooldown)
end

local DISPEL_ORDER = { "Magic", "Curse", "Disease", "Poison" }

-- Removable debuffs on a health bar: one slot per debuff type your class can
-- remove. A slot only exists on screen while a debuff of its type is on the
-- unit, and carries the colour wash over the bar plus the debuff's icon.
-- washOnly: just the colour over the bar, no icon (raid cells list the debuff
-- itself with the others, bottom left).
local function RemovableContainer(owner, health, iconSize, washOnly, strength)
    local container = NewContainer(owner)
    container:SetPoint("CENTER", health, "CENTER")
    local level = health:GetFrameLevel() + 2
    local count = 0
    for _, kind in ipairs(DISPEL_ORDER) do
        if MINE[kind] then
            local color, column = TYPE_COLOR[kind], count
            count = count + 1
            container:AddAuraSlot(kind, "HARMFUL", {
                candidateFilters = { includeDispelTypes = { [kind] = true }, excludeSpellIDs = IGNORE_ID },
                initializeFrame = function(slot)
                    -- placement has to happen here: the game refuses it later, mid-fight
                    -- every type sits dead centre; if two types are on the unit at
                    -- once the first in the list (Magic first) is drawn on top
                    slot:ClearAllPoints()
                    slot:SetPoint("CENTER", health, "CENTER", 0, 0)
                    slot:SetFrameLevel(level + (4 - column))
                    local wash = slot:CreateTexture(nil, "BACKGROUND", nil, -8)
                    wash:SetAllPoints(health)
                    wash:SetColorTexture(color[1], color[2], color[3], strength or 0.5)
                    if washOnly then
                        local icon = slot:CreateTexture(nil, "ARTWORK")
                        icon:SetAlpha(0)
                        slot:SetSize(1, 1)
                        slot:SetIcon(icon)
                        if slot.EnableMouse then slot:EnableMouse(false) end
                    else
                        DressButton(slot, iconSize, false)
                    end
                end,
            })
        end
    end
    if count == 0 then return nil end
    return container
end

local function BindContainers(list, unit)
    for _, container in ipairs(list) do
        container:SetUnit(unit or "none") -- "none" is the game's own "nobody" binding
        container:UpdateAllAuras()
    end
end

-- Every debuff on the member that you can remove, in the middle of the
-- cell, each with its stack count. One on its own is drawn at full size;
-- two or more are each drawn at half that, side by side.
--
-- The game owns these buttons and will not let them be resized during a
-- fight, so the buttons themselves stay half size the whole time. What
-- changes is only the picture drawn on a button, which is ours to resize:
-- when exactly one button is showing, its picture is drawn large.
local function DispelGroup(d, button, S)
    if not next(MINE) then return nil end
    local big = math.max(12, S.dispelSize or 22)
    local small = math.max(8, math.floor(big / 2 + 0.5))
    local container = NewContainer(button)
    container:SetPoint("CENTER", d.health, "CENTER")
    container:SetFrameLevel(d.health:GetFrameLevel() + 9)

    local parts = {} -- button -> its picture
    local order = {}
    local function Resize()
        local showing = 0
        for _, b in ipairs(order) do
            if b:IsShown() then showing = showing + 1 end
        end
        local size = showing <= 1 and big or small
        for _, b in ipairs(order) do
            local icon = parts[b]
            if icon.size ~= size then
                icon.size = size
                icon.texture:SetSize(size, size)
                if icon.count then ns.SetFont(icon.count, math.max(9, math.floor(size * 0.55))) end
            end
        end
    end
    local SafeResize = ns.Safe("dispellable debuffs", Resize)
    local queued = false
    local function Queue()
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            SafeResize()
        end)
    end
    d.dispelRefresh = Queue

    local types = {}
    for kind in pairs(MINE) do types[kind] = true end
    container:AddAuraGroup("dispel", "HARMFUL", {
        maxFrameCount = 4,
        candidateFilters = { includeDispelTypes = types, excludeSpellIDs = IGNORE_ID },
        initializeFrame = function(b)
            b:SetSize(small, small)
            local texture = b:CreateTexture(nil, "ARTWORK")
            texture:SetPoint("CENTER", b, "CENTER")
            texture:SetSize(small, small)
            texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local edge = b:CreateTexture(nil, "BACKGROUND")
            edge:SetColorTexture(0, 0, 0, 1)
            edge:SetPoint("TOPLEFT", texture, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", 1, -1)
            b:SetIcon(texture)
            local icon = { texture = texture, size = small }
            if S.stacks ~= false then icon.count = StackCount(b, texture, 10) end
            parts[b] = icon
            order[#order + 1] = b
            b:HookScript("OnShow", Queue)
            b:HookScript("OnHide", Queue)
            ns.AuraTooltip(b, nil)
        end,
        layout = { elementWidth = small, elementHeight = small, elementSpacing = 2, lineSpacing = 2 },
    })
    return container
end

-- All of a group cell's aura displays.
local function CellContainers(d, button, cfg)
    local S = cfg.S
    local list = {}
    local level = d.health:GetFrameLevel() + 8 -- above the "you can remove this" colour

    -- the colour over the whole cell while there is something you can remove
    if S.dispelTint ~= false then
        local tint = RemovableContainer(button, d.health, cfg.height - 8, true, S.tintStrength)
        if tint then list[#list + 1] = tint end
    end
    -- the removable debuffs themselves, in the middle
    local dispel = DispelGroup(d, button, S)
    if dispel then list[#list + 1] = dispel end

    -- every other debuff
    if (S.debuffCount or 0) > 0 then
        local size = S.debuffSize or 14
        local others = NewContainer(button)
        PlaceAt(others, button, d.health, S.debuffSpot)
        others:SetFrameLevel(level)
        local candidates = { excludeSpellIDs = IGNORE_ID }
        if next(MINE) then candidates.excludeDispelTypes = MINE end -- those are in the middle
        others:AddAuraGroup("others", "HARMFUL", {
            maxFrameCount = S.debuffCount,
            candidateFilters = candidates,
            initializeFrame = function(b) DressButton(b, size, true, S.stacks ~= false) end,
            layout = { elementWidth = size, elementHeight = size, elementSpacing = 2, lineSpacing = 2 },
        })
        list[#list + 1] = others
    end

    -- buffs you put on them (blessings, heals over time...)
    if (S.buffCount or 0) > 0 then
        local size = S.buffSize or 12
        local mineFilter = { isFromPlayerOrPlayerPet = true, excludeSpellIDs = { [OATH_ID] = true } }
        -- Short buffs only (heals over time, shields, brief protections), so
        -- blessings and other long raid buffs do not fill the row. The game
        -- drops anything longer than this many seconds, and anything with no
        -- timer at all. 0 switches the limit off.
        if (S.buffMaxSeconds or 0) > 0 then mineFilter.maxDuration = S.buffMaxSeconds end
        local mine = NewContainer(button)
        PlaceAt(mine, button, d.health, S.buffSpot)
        mine:SetFrameLevel(level)
        mine:AddAuraGroup("mine", "HELPFUL|PLAYER", {
            maxFrameCount = S.buffCount,
            -- Only buffs that you (or your pet) cast. The "PLAYER" word in the
            -- filter is not enough on its own: in a raid it let through everyone
            -- else's buffs too. The Oath is left out; it has its own marker.
            candidateFilters = mineFilter,
            initializeFrame = function(b) DressButton(b, size, true, false) end,
            layout = { elementWidth = size, elementHeight = size, elementSpacing = 2, lineSpacing = 2 },
        })
        list[#list + 1] = mine
    end

    -- Oath of Light marker, on every paladin. (It used to be built only when
    -- the game said the talent was known at login; that answer is not
    -- reliable that early, and a slot that never matches costs nothing.)
    if select(2, UnitClass("player")) == "PALADIN" then
        local oath = NewContainer(button)
        local size = cfg.row and math.max(10, cfg.height - 12) or 12
        oath:SetPoint("CENTER", d.health, "CENTER")
        oath:AddAuraSlot("oath", "HELPFUL", {
            candidateFilters = { isFromPlayerOrPlayerPet = true, includeSpellIDs = { [OATH_ID] = true } }, -- yours, not another paladin's
            initializeFrame = function(slot)
                if cfg.row then
                    slot:SetPoint("RIGHT", d.status, "LEFT", -8, 0)
                else
                    slot:SetPoint("BOTTOMRIGHT", d.health, "BOTTOMRIGHT", -2, 2)
                end
                slot:SetFrameLevel(d.health:GetFrameLevel() + 4)
                DressButton(slot, size, true)
            end,
        })
        list[#list + 1] = oath
    end

    BindContainers(list, d.unit)
    if d.dispelRefresh then d.dispelRefresh() end
    return list
end

-- Used by the player frame for its own removable debuffs (see UnitFrames.lua).
function ns.RemovableOn(owner, health, iconSize, unit)
    local container = RemovableContainer(owner, health, iconSize)
    if container then BindContainers({ container }, unit) end
    return container
end

-- The player frame uses the same display (see UnitFrames.lua).
ns.MiddleSlots = MiddleSlots
ns.UpdateRemovableDebuffs = function(holder)
    BuildCurves()
    UpdateAuras(holder)
end

-- Outlines: aggro around the outside of the cell, "is my target" just inside it.
local function UpdateBorder(d)
    local unit = d.unit

    -- red while a mob is attacking them, orange when they are close to pulling one
    local threat = d.cfg.S.aggro ~= false and Clean(UnitThreatSituation(unit)) or nil
    if threat and threat >= 2 then
        d.aggro:SetColorTexture(0.95, 0.12, 0.12, 1)
        d.aggro:Show()
    elseif threat == 1 then
        d.aggro:SetColorTexture(1, 0.6, 0.1, 1)
        d.aggro:Show()
    else
        d.aggro:Hide()
    end

    if Clean(UnitIsUnit(unit, "target")) then
        d.border:Show(1, 1, 1)
    else
        d.border:Hide()
    end
end

local READY = {
    ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

local function UpdateIcons(d)
    local unit = d.unit
    d.leader:SetShown(Clean(UnitIsGroupLeader(unit)) and true or false)

    local index = Clean(GetRaidTargetIndex(unit))
    if index then
        SetRaidTargetIconTexture(d.mark, index)
        d.mark:Show()
    else
        d.mark:Hide()
    end

    local state = Clean(GetReadyCheckStatus(unit))
    if state and READY[state] then
        d.ready:SetTexture(READY[state])
        d.ready:Show()
    else
        d.ready:Hide()
    end

    -- someone is already casting a resurrection on this member: the game's own
    -- rez icon in the middle of the cell, so you can pick somebody else
    if d.rez then
        local coming = UnitHasIncomingResurrection and Clean(UnitHasIncomingResurrection(unit))
        d.rez:SetShown(coming and true or false)
        if coming then d.ready:Hide() end
    end
end


local function UpdateAll(d)
    local unit = d.unit
    if not unit or not UnitExists(unit) then return end
    local S = d.cfg.S
    local name = UnitName(unit)
    local limit = S.nameLength or 0
    if limit > 0 and type(name) == "string" and not ns.IsSecret(name) then
        -- whole characters only (names can have accented letters)
        name = name:match("^" .. ("[%z\1-\127\194-\244][\128-\191]*"):rep(limit)) or name
    end
    d.name:SetText(name)
    d.nameR, d.nameG, d.nameB = nil, nil, nil
    if S.nameColor == "class" then
        local r, g, b = ns.ClassColorOf(unit)
        if ns.IsSecret(r) or r then d.nameR, d.nameG, d.nameB = r, g, b end
    end
    PaintBar(d, unit)
    UpdateHealth(d)
    UpdatePower(d)
    UpdateIcons(d)
    UpdateBorder(d)
    UpdateAuras(d)
end

local function UpdateRange(d)
    local unit, button = d.unit, d.button
    local FAR_ALPHA = d.cfg.S.rangeAlpha or 0.45
    if Clean(UnitIsUnit(unit, "player")) then
        button:SetAlpha(1)
        return
    end
    if Clean(UnitIsConnected(unit)) == false then
        button:SetAlpha(FAR_ALPHA)
        return
    end
    local inRange, checked = UnitInRange(unit)
    if ns.IsSecret(inRange) then
        if button.SetAlphaFromBoolean then button:SetAlphaFromBoolean(inRange, 1, FAR_ALPHA) end
    else
        button:SetAlpha((inRange or Clean(checked) == false) and 1 or FAR_ALPHA)
    end
end

---------------------------------------------------------------------------
-- Styling one header button
---------------------------------------------------------------------------
local function Style(button, cfg)
    if cells[button] then return end
    local d = { button = button, cfg = cfg }
    cells[button] = d

    button:SetSize(cfg.width, cfg.height)
    button:RegisterForClicks("AnyUp")
    local menuButton = ns.AttachMenu(button)
    -- Click-casting (set up in /keebui, Frames, Click casting). Only the
    -- combinations you have bound do anything; the catch-all "any click
    -- targets / opens the menu" the cell started with is removed.
    button:SetAttribute("*type1", nil)
    button:SetAttribute("*type2", nil)
    button:SetAttribute("*macrotext2", nil)
    for key, action in pairs(ns.ClickCasts()) do
        local prefix, number = key:match("^(.-)(%d)$")
        if prefix and type(action) == "string" and action ~= "" then
            if action == "target" then
                button:SetAttribute(prefix .. "type" .. number, "target")
            elseif action == "menu" then
                button:SetAttribute(prefix .. "type" .. number, "macro")
                button:SetAttribute(prefix .. "macrotext" .. number, "/click " .. menuButton)
            else
                button:SetAttribute(prefix .. "type" .. number, "spell")
                button:SetAttribute(prefix .. "spell" .. number, action)
            end
        end
    end
    ns.Edge(button)

    d.health = ns.Bar(button)
    d.health:SetAllPoints()
    d.incoming = ns.HealPrediction(d.health)

    local top = CreateFrame("Frame", nil, button)
    top:SetAllPoints()
    top:SetFrameLevel(d.health:GetFrameLevel() + 3)

    d.name = ns.Text(top, cfg.text, cfg.row and "LEFT" or "CENTER")
    d.status = ns.Text(top, cfg.text, cfg.row and "RIGHT" or "CENTER")
    if cfg.S.heals == false then d.incoming:Hide() end

    -- optional thin power bar along the bottom (its own frame: the health bar clips what is inside it)
    if cfg.S.power == "mana" or cfg.S.power == "all" then
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetStatusBarTexture(ns.FLAT)
        bar:SetFrameLevel(d.health:GetFrameLevel() + 2)
        bar:SetPoint("BOTTOMLEFT")
        bar:SetPoint("BOTTOMRIGHT")
        bar:SetHeight(3)
        local back = bar:CreateTexture(nil, "BACKGROUND")
        back:SetPoint("TOPLEFT", 0, 1)
        back:SetPoint("BOTTOMRIGHT")
        back:SetColorTexture(0, 0, 0, 1)
        bar:Hide()
        d.power = bar
    end
    if cfg.row then
        d.status:SetPoint("RIGHT", -5, 0)
        d.name:SetPoint("LEFT", 5, 0)
        d.name:SetPoint("RIGHT", d.status, "LEFT", -4, 0)
    else
        d.name:SetPoint("LEFT", 3, 5)
        d.name:SetPoint("RIGHT", -3, 5)
        d.status:SetPoint("BOTTOM", 0, 4)
    end

    d.border = ns.InnerBorder(top)

    -- aggro outline: a red rim just outside the cell's black edge
    local rim = CreateFrame("Frame", nil, button)
    rim:SetFrameLevel(math.max(button:GetFrameLevel() - 1, 0))
    rim:SetPoint("TOPLEFT", -3, 3)
    rim:SetPoint("BOTTOMRIGHT", 3, -3)
    d.aggro = rim:CreateTexture(nil, "BACKGROUND")
    d.aggro:SetAllPoints()
    d.aggro:Hide()

    d.middle = MiddleSlots(top, cfg.height - 8)

    -- Oath of Light marker: party rows have room beside the percentage; raid
    -- cells get a small one in the top-right corner
    if cfg.row then
        d.oath = ns.AuraIcon(top, cfg.height - 12)
        d.oath:SetPoint("RIGHT", d.status, "LEFT", -8, 0)
    else
        d.oath = ns.AuraIcon(top, 12)
        d.oath:SetPoint("TOPRIGHT", -2, -2)
    end

    d.leader = top:CreateTexture(nil, "OVERLAY", nil, 6)
    d.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    d.leader:SetSize(16, 16)
    d.leader:SetPoint("CENTER", top, "TOPLEFT", 3, -1)
    d.leader:Hide()

    d.mark = top:CreateTexture(nil, "OVERLAY", nil, 2)
    d.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    d.mark:SetSize(14, 14)
    d.mark:SetPoint("CENTER", top, "TOP", 0, -1)
    d.mark:Hide()

    d.ready = top:CreateTexture(nil, "OVERLAY", nil, 3)
    d.ready:SetSize(18, 18)
    d.ready:SetPoint("CENTER")
    d.ready:Hide()
    d.rez = top:CreateTexture(nil, "OVERLAY", nil, 4)
    d.rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    d.rez:SetSize(22, 22)
    d.rez:SetPoint("CENTER")
    d.rez:Hide()
    -- "an enemy is casting at them": a bright strip along the top of the cell.
    -- One strip per enemy caster being watched, all in the same place.
    d.castAt = {}
    for i = 1, 4 do
        local strip = top:CreateTexture(nil, "OVERLAY", nil, 6)
        strip:SetColorTexture(1, 0.85, 0.1, 1)
        strip:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        strip:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        strip:SetHeight(3)
        strip:SetAlpha(0)
        d.castAt[i] = strip
    end

    local hover = top:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.1)
    hover:Hide()

    if cfg.debuffs then
        d.debuffs = {}
        for i = 1, cfg.debuffs do
            local icon = ns.AuraIcon(button, 20)
            if i == 1 then
                icon:SetPoint("LEFT", button, "RIGHT", 4, 0)
            else
                icon:SetPoint("LEFT", d.debuffs[i - 1], "RIGHT", 3, 0)
            end
            d.debuffs[i] = icon
        end
    end

    do
        local ok, list = pcall(CellContainers, d, button, cfg)
        if ok then
            d.containers = list
            if d.oath then d.oath:Hide() end
        else
            ns.LogError("cell aura containers", list)
        end
    end

    local refresh = ns.Safe("group cell", UpdateAll)
    button:HookScript("OnAttributeChanged", function(_, key, value)
        if key ~= "unit" then return end
        if d.unit and byUnit[d.unit] == button then byUnit[d.unit] = nil end
        d.unit = value
        if d.containers then
            local ok, err = pcall(BindContainers, d.containers, value)
            if not ok then ns.LogError("cell aura containers (unit)", err) end
        end
        if value then
            byUnit[value] = button
            refresh(d)
        end
    end)
    button:HookScript("OnShow", function() refresh(d) end)
    button:HookScript("OnEnter", function(self)
        hover:Show()
        if not d.unit then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        if pcall(GameTooltip.SetUnit, GameTooltip, d.unit) then GameTooltip:Show() end
    end)
    button:HookScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)

    -- lets click-casting addons find these frames
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true

    local unit = button:GetAttribute("unit")
    if unit then
        d.unit = unit
        byUnit[unit] = button
        if d.containers then pcall(BindContainers, d.containers, unit) end
        refresh(d)
    end
end

---------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------
local function MakeHeader(name, anchor, cfg, count, attributes)
    local header = CreateFrame("Frame", name, anchor, "SecureGroupHeaderTemplate")
    if cfg.growUp then
        header:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
    else
        header:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    end
    header:SetAttribute("template", "SecureUnitButtonTemplate")
    header:SetAttribute("templateType", "Button")
    header:SetAttribute("initialConfigFunction", ([[
        self:SetWidth(%d)
        self:SetHeight(%d)
        self:SetAttribute("*type1", "target")
    ]]):format(cfg.width, cfg.height))
    header:SetAttribute("point", cfg.growUp and "BOTTOM" or "TOP")
    header:SetAttribute("yOffset", cfg.growUp and cfg.gap or -cfg.gap)
    for key, value in pairs(attributes) do header:SetAttribute(key, value) end
    header:Show()

    -- Make every button now, out of combat, so none has to be created mid-fight.
    header:SetAttribute("startingIndex", 1 - count)
    header:SetAttribute("startingIndex", 1)
    for i = 1, count do
        local button = header:GetAttribute("child" .. i)
        if button then Style(button, cfg) end
    end
    return header
end

local UNIT_EVENTS = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateHealth,
    UNIT_HEAL_PREDICTION = UpdateHealth,
    UNIT_AURA = UpdateAuras,
    UNIT_THREAT_SITUATION_UPDATE = UpdateBorder,
    UNIT_NAME_UPDATE = UpdateAll,
}
local POWER_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

---------------------------------------------------------------------------
-- Incoming casts. While an enemy whose nameplate is on screen is casting,
-- whoever it is casting at gets a bright strip along the top of their cell.
--
-- In combat the game will not tell an addon who an enemy is targeting: the
-- answer to "is that enemy's target this raid member" comes back as a value
-- that cannot be looked at. It can still be handed to the strip, which then
-- shows or hides itself. So nothing here ever learns who is being cast at;
-- each cell's strip is simply given the answer for that cell.
---------------------------------------------------------------------------
local CAST_SLOTS = 4

local function InitIncomingCasts()
    local casting = {} -- enemy unit ("nameplate7") -> true while it is casting
    local order = {}   -- up to CAST_SLOTS of them, in a stable order
    local any = false

    local function Light(strip, caster, member)
        local ok, same = pcall(UnitIsUnit, caster .. "target", member)
        if not ok then
            strip:SetAlpha(0)
        elseif ns.IsSecret(same) then
            if strip.SetAlphaFromBoolean then
                strip:SetAlphaFromBoolean(same, 1, 0)
            else
                strip:SetAlpha(0) -- no way to use the answer on this client
            end
        else
            strip:SetAlpha(same and 1 or 0)
        end
    end

    local function Paint()
        wipe(order)
        for unit in pairs(casting) do
            if UnitExists(unit) then order[#order + 1] = unit else casting[unit] = nil end
        end
        table.sort(order)
        any = #order > 0
        for button, d in pairs(cells) do
            if d.castAt then
                local live = d.unit and button:IsVisible() and d.cfg.S.castStrip ~= false
                for slot = 1, CAST_SLOTS do
                    local caster = live and order[slot]
                    if caster then
                        Light(d.castAt[slot], caster, d.unit)
                    else
                        d.castAt[slot]:SetAlpha(0)
                    end
                end
            end
        end
    end
    local SafePaint = ns.Safe("incoming casts", Paint)

    local STARTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }
    local STOPS = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
        UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_FAILED = true }
    local events = CreateFrame("Frame")
    for event in pairs(STARTS) do events:RegisterEvent(event) end
    for event in pairs(STOPS) do events:RegisterEvent(event) end
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("UNIT_TARGET")
    events:SetScript("OnEvent", function(_, event, unit)
        if type(unit) ~= "string" or not unit:find("^nameplate") then return end
        if STARTS[event] then
            -- enemies only; where the game will not say, assume it is one
            local ok, hostile = pcall(UnitCanAttack, "player", unit)
            if ok and (ns.IsSecret(hostile) or hostile) then casting[unit] = true end
        elseif STOPS[event] or event == "NAME_PLATE_UNIT_REMOVED" then
            if not casting[unit] then return end
            casting[unit] = nil
        elseif not casting[unit] then
            return -- a target change by something that is not casting
        end
        SafePaint()
    end)
    -- a caster can pick a new target mid-cast, and members come and go
    C_Timer.NewTicker(0.25, function()
        if any or next(casting) then SafePaint() end
    end)
end

local started = false
local function Start()
    if started then return end
    started = true
    if not mineIcon then pcall(BuildCurves) end
    pcall(InitIncomingCasts)

    -- power events are frequent, so they are only listened to if a power bar is switched on
    for _, kind in ipairs({ "party", "raid" }) do
        local power = ns.FrameSettings(kind).power
        if power == "mana" or power == "all" then
            for _, event in ipairs(POWER_EVENTS) do UNIT_EVENTS[event] = UpdatePower end
        end
    end

    local events = CreateFrame("Frame")
    for event in pairs(UNIT_EVENTS) do events:RegisterEvent(event) end
    -- a resurrection cast on a member starting or stopping (not every client has this event)
    if pcall(events.RegisterEvent, events, "INCOMING_RESURRECT_CHANGED") then
        UNIT_EVENTS.INCOMING_RESURRECT_CHANGED = UpdateIcons
    end
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PARTY_LEADER_CHANGED",
        "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", ns.Safe("group event", function(_, event, unit)
        local handler = UNIT_EVENTS[event]
        if handler then
            local button = unit and byUnit[unit]
            local d = button and cells[button]
            if d and d.unit == unit and UnitExists(unit) then handler(d) end
        else
            for _, d in pairs(cells) do UpdateAll(d) end
        end
    end))

    C_Timer.NewTicker(0.3, ns.Safe("group range", function()
        for button, d in pairs(cells) do
            if d.unit and button:IsVisible() then UpdateRange(d) end
        end
    end))
end

local function InitParty()
    Start()
    local PARTY = Config("party")
    local S = PARTY.S
    local rows = S.showPlayer and 5 or 4
    local height = rows * PARTY.height + (rows - 1) * PARTY.gap
    -- bottom edge sits above the cooldown icons that rest on the player frame
    local bottom = (ns.FRAME_Y or 221) + 22 + 70
    local anchor = ns.Anchor("party", "Party", PARTY.width, height, -250, bottom + height / 2)
    local header = MakeHeader("KeebUIParty", anchor, PARTY, rows, {
        showParty = true,
        showPlayer = S.showPlayer and true or false,
        sortMethod = "INDEX",
    })
    -- In a raid the raid grid already shows your own group, so the party
    -- column steps aside. The game does the hiding itself (a state driver),
    -- which is the only way that works when a raid forms mid-combat.
    if RegisterStateDriver then
        RegisterStateDriver(header, "visibility", "[group:raid] hide; show")
    end
    ns.Retire("PartyFrame")
    ns.Retire("CompactPartyFrame")
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        pcall(function()
            for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
                frame:UnregisterAllEvents()
            end
        end)
    end
end

-- Which raid size applies: the one you picked, or (on "auto") by how many are in the raid.
local RAID_SIZES = { ["10"] = true, ["20"] = true, ["40"] = true }
local function RaidPreset()
    local choice = ns.db.raidPreset
    if RAID_SIZES[choice] then return choice end
    local members = GetNumGroupMembers() or 0
    if members <= 10 then return "10" end
    if members <= 20 then return "20" end
    return "40"
end

local function InitRaid()
    Start()
    local RAID = Config("raid")
    local S = RAID.S
    -- Raid cell sizes for three raid sizes. Smaller raids get bigger cells, so
    -- the grid is easy to read at 10 and still fits on screen at 40.
    local function Preset(name)
        return { width = S["w" .. name], height = S["h" .. name], text = S["t" .. name] }
    end
    -- groups as columns (5 down, 8 across) or as rows (5 across, 8 down)
    local asRows = S.orientation == "ROWS"
    local function Block(width, height)
        if asRows then return 5 * width + 4 * RAID.gap, 8 * height + 7 * RAID.gap end
        return 8 * width + 7 * RAID.gap, 5 * height + 4 * RAID.gap
    end

    local width, height = Block(RAID.width, RAID.height)
    local anchor = ns.Anchor("raid", "Raid", width, height, -500, 640)

    -- The headers that hold the cells.
    --
    -- Sorted by group, each raid group gets a header of its own: group 3 is
    -- always the third column (or row), whether or not groups 1 and 2 are
    -- full. (One header for the whole raid cannot do that: it just pours
    -- members into columns of five, so a group of three would be topped up
    -- with two members of the next group.)
    --
    -- Sorted by class or by name there are no groups to keep apart, so one
    -- header fills the grid five at a time.
    local headers = {} -- { header, how many cells it has }
    local perGroup = S.sort ~= "CLASS" and S.sort ~= "NAME"
    local function Base()
        local attributes = { showRaid = true, unitsPerColumn = 5, columnSpacing = RAID.gap,
            columnAnchorPoint = asRows and "TOP" or "LEFT" }
        if asRows then
            attributes.point, attributes.xOffset, attributes.yOffset = "LEFT", RAID.gap, 0
        end
        return attributes
    end
    if perGroup then
        for group = 1, 8 do
            local attributes = Base()
            attributes.groupFilter = tostring(group)
            attributes.sortMethod = "INDEX"
            attributes.maxColumns = 1
            headers[group] = { MakeHeader("KeebUIRaid" .. group, anchor, RAID, 5, attributes), 5 }
        end
    else
        local attributes = Base()
        attributes.groupFilter = "1,2,3,4,5,6,7,8"
        attributes.maxColumns = 8
        attributes.sortMethod = "NAME"
        if S.sort == "CLASS" then
            attributes.groupBy = "CLASS"
            attributes.groupingOrder = "WARRIOR,PALADIN,PRIEST,DRUID,SHAMAN,MAGE,WARLOCK,HUNTER,ROGUE"
        end
        headers[1] = { MakeHeader("KeebUIRaid", anchor, RAID, 40, attributes), 40 }
    end
    -- side by side (or stacked) at the current cell size
    local function PlaceHeaders(cellWidth, cellHeight)
        if not perGroup then return end
        for group, entry in ipairs(headers) do
            local header = entry[1]
            header:ClearAllPoints()
            if asRows then
                header:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(group - 1) * (cellHeight + RAID.gap))
            else
                header:SetPoint("TOPLEFT", anchor, "TOPLEFT", (group - 1) * (cellWidth + RAID.gap), 0)
            end
        end
    end
    PlaceHeaders(RAID.width, RAID.height)
    ns.Retire("CompactRaidFrameContainer")

    -- Resize every cell to the current preset. These are protected frames, so
    -- it can only happen out of combat; a change during a fight waits for it to end.
    local applied, waiting
    local function ApplyPreset()
        local name = RaidPreset()
        if name == applied then return end
        if InCombatLockdown() then
            waiting = true
            return
        end
        waiting = false
        applied = name
        local preset = Preset(name)
        for _, entry in ipairs(headers) do
            for n = 1, entry[2] do
                local button = entry[1]:GetAttribute("child" .. n)
                if button then
                    button:SetSize(preset.width, preset.height)
                    local d = cells[button]
                    if d then
                        ns.SetFont(d.name, preset.text)
                        ns.SetFont(d.status, preset.text)
                    end
                end
            end
        end
        PlaceHeaders(preset.width, preset.height)
        anchor:SetSize(Block(preset.width, preset.height))
        -- Each size remembers its own position: dragging the raid block while
        -- it is at the 20-man size only moves the 20-man spot. A size that has
        -- never been moved starts where you last had the raid block.
        local spot = "raid" .. name
        if not ns.db.pos[spot] then
            local from = ns.db.pos[anchor.key] or ns.db.pos.raid
            if from then ns.db.pos[spot] = { from[1], from[2] } end
        end
        anchor.key = spot
        if anchor.labelText then anchor.labelText:SetText("Raid (" .. name .. ")") end
        ns.PlaceAnchors()
        for _, entry in ipairs(headers) do
            local header = entry[1]
            -- cells made later (there should be none) would use the new size too
            header:SetAttribute("initialConfigFunction", ([[
                self:SetWidth(%d)
                self:SetHeight(%d)
                self:SetAttribute("*type1", "target")
            ]]):format(preset.width, preset.height))
            -- nudging an attribute makes the game lay the cells out again
            header:SetAttribute("unitsPerColumn", 5)
        end
    end
    ns.ApplyRaidPreset = ns.Safe("raid size", ApplyPreset)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_REGEN_ENABLED" or waiting then ns.ApplyRaidPreset() end
    end)
    ns.ApplyRaidPreset()
end

ns.modules[#ns.modules + 1] = { setting = "party", init = InitParty }
ns.modules[#ns.modules + 1] = { setting = "raid", init = InitRaid }
