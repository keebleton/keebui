-- KeebUI raid and party frame settings: a window of its own, with a live
-- preview. The preview is a mock-up drawn from the same settings (made-up
-- members, health and debuffs), so you can tune everything without being in
-- a group. The real frames pick most changes up at the next reload: they are
-- protected by the game and are built once, at login.

local ADDON, ns = ...

local GOLD = { 0.95, 0.76, 0.19 }
local WIDTH, ROW, PAD = 580, 38, 18
local TABS = { "Layout", "Cell", "Auras", "Health" }

local window
local kind, tab, editSize = "raid", "Layout", "40"
local dirty = false
local Refresh -- repaints every control and the preview

local function S() return ns.FrameSettings(kind) end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------
local CLASS_MANA = { PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true }
local FAKE = {
    { name = "Thorgrim", class = "WARRIOR", hp = 0.55, aggro = true, debuffs = 2 },
    { name = "Elowen", class = "PRIEST", hp = 1, buffs = 2, power = 0.7 },
    { name = "Kazrik", class = "ROGUE", hp = 0.8, dispel = 1, stack = 3 },
    { name = "Maribel", class = "MAGE", hp = 0.35, dispel = 2, cast = true, power = 0.4, heal = 0.25 },
    { name = "Brannoc", class = "DRUID", hp = 1, buffs = 1, far = true, power = 0.9 },
    { name = "Sylvara", class = "HUNTER", hp = 0.9, debuffs = 4, power = 0.6 },
    { name = "Grushak", class = "SHAMAN", hp = 0, dead = true },
    { name = "Anselm", class = "PALADIN", hp = 0.7, heal = 0.2, buffs = 4, power = 0.55 },
    { name = "Vexia", class = "WARLOCK", hp = 1, offline = true },
    { name = "Dunmar", class = "WARRIOR", hp = 0.95, debuffs = 1, stack = 5 },
}
local DEBUFF_ICONS = { "Interface\\Icons\\Spell_Shadow_CurseOfTounges", "Interface\\Icons\\Ability_Creature_Disease_02",
    "Interface\\Icons\\Spell_Frost_FrostNova", "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Ability_Gouge" }
local BUFF_ICONS = { "Interface\\Icons\\Spell_Holy_FistOfJustice", "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    "Interface\\Icons\\Spell_Holy_Renew", "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings", "Interface\\Icons\\Spell_Holy_PrayerOfHealing" }
local DISPEL_ICONS = { "Interface\\Icons\\Spell_Nature_Polymorph", "Interface\\Icons\\Ability_Creature_Poison_03" }
local FAKE_MAX = 5200

local preview = { cells = {}, shown = false }

local function Short(n)
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return ("%d"):format(n)
end

local function NewPreviewCell(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.rim = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.rim:SetPoint("TOPLEFT", -3, 3)
    c.rim:SetPoint("BOTTOMRIGHT", 3, -3)
    c.rim:SetColorTexture(0.95, 0.12, 0.12, 1)
    c.edge = c:CreateTexture(nil, "BACKGROUND", nil, -7)
    c.edge:SetPoint("TOPLEFT", -1, 1)
    c.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    c.edge:SetColorTexture(0, 0, 0, 1)
    c.back = c:CreateTexture(nil, "BACKGROUND", nil, -6)
    c.back:SetAllPoints()
    c.back:SetColorTexture(0.07, 0.07, 0.07, 1)
    c.fill = c:CreateTexture(nil, "BORDER")
    c.fill:SetPoint("TOPLEFT")
    c.fill:SetPoint("BOTTOMLEFT")
    c.heal = c:CreateTexture(nil, "BORDER", nil, 1)
    c.heal:SetColorTexture(0.35, 0.95, 0.45, 0.55)
    c.heal:SetPoint("TOPLEFT", c.fill, "TOPRIGHT")
    c.heal:SetPoint("BOTTOMLEFT", c.fill, "BOTTOMRIGHT")
    c.tint = c:CreateTexture(nil, "ARTWORK")
    c.tint:SetAllPoints()
    c.powerBack = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.powerBack:SetColorTexture(0, 0, 0, 1)
    c.powerBack:SetPoint("BOTTOMLEFT")
    c.powerBack:SetPoint("BOTTOMRIGHT")
    c.powerBack:SetHeight(4)
    c.power = c:CreateTexture(nil, "ARTWORK", nil, 2)
    c.power:SetPoint("BOTTOMLEFT")
    c.power:SetHeight(3)
    c.strip = c:CreateTexture(nil, "OVERLAY", nil, 6)
    c.strip:SetColorTexture(1, 0.85, 0.1, 1)
    c.strip:SetPoint("TOPLEFT")
    c.strip:SetPoint("TOPRIGHT")
    c.strip:SetHeight(3)
    c.name = ns.Text(c, 12, "CENTER")
    c.status = ns.Text(c, 12, "CENTER")
    c.icons = {} -- pooled pictures, each with a black edge and a number
    c.rows = {}  -- holders for a row of icons
    return c
end

local function Icon(c, n)
    local icon = c.icons[n]
    if not icon then
        icon = {}
        icon.edge = c:CreateTexture(nil, "OVERLAY", nil, 1)
        icon.edge:SetColorTexture(0, 0, 0, 1)
        icon.tex = c:CreateTexture(nil, "OVERLAY", nil, 2)
        icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.edge:SetPoint("TOPLEFT", icon.tex, "TOPLEFT", -1, 1)
        icon.edge:SetPoint("BOTTOMRIGHT", icon.tex, "BOTTOMRIGHT", 1, -1)
        icon.count = ns.Text(c, 10, "RIGHT")
        icon.count:SetPoint("BOTTOMRIGHT", icon.tex, "BOTTOMRIGHT", 2, -2)
        c.icons[n] = icon
    end
    return icon
end

local function Holder(c, n)
    local holder = c.rows[n]
    if not holder then
        holder = CreateFrame("Frame", nil, c)
        c.rows[n] = holder
    end
    holder:ClearAllPoints()
    return holder
end

-- A row of `count` pictures of `size` at `spot`; returns how many icons it used.
local function IconRow(c, used, holderIndex, textures, count, size, spot, stack, lift)
    if count <= 0 then return used end
    local holder = Holder(c, holderIndex)
    holder:SetSize(count * size + (count - 1) * 2, size)
    if spot == "CENTER" then
        holder:SetPoint("CENTER")
    else
        ns.GroupPlaceAt(holder, c, c, spot, lift)
    end
    holder:Show()
    for i = 1, count do
        used = used + 1
        local icon = Icon(c, used)
        icon.tex:ClearAllPoints()
        icon.tex:SetSize(size, size)
        icon.tex:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + 2), 0)
        icon.tex:SetTexture(textures[(i - 1) % #textures + 1])
        icon.tex:Show()
        icon.edge:Show()
        if stack and i == 1 then
            ns.SetFont(icon.count, math.max(9, math.floor(size * 0.55)))
            icon.count:SetText(stack)
            icon.count:Show()
        else
            icon.count:Hide()
        end
    end
    return used
end

local function DrawCell(c, set, row, width, height, textSize, data)
    c:SetSize(width, height)
    c:SetAlpha((data.far or data.offline) and (set.rangeAlpha or 0.45) or 1)

    -- bar
    local color = RAID_CLASS_COLORS[data.class] or { r = 0.5, g = 0.5, b = 0.5 }
    local hp = data.dead and 0 or data.hp
    if set.barColor == "dark" then
        c.fill:SetColorTexture(0.2, 0.21, 0.2, 1)
    elseif set.barColor == "health" then
        if hp > 0.5 then
            local t = (hp - 0.5) * 2
            c.fill:SetColorTexture(0.9 + (0.25 - 0.9) * t, 0.75 + (0.72 - 0.75) * t, 0.15 + (0.3 - 0.15) * t, 1)
        else
            local t = hp * 2
            c.fill:SetColorTexture(0.85 + (0.9 - 0.85) * t, 0.18 + (0.75 - 0.18) * t, 0.18 + (0.15 - 0.18) * t, 1)
        end
    else
        c.fill:SetColorTexture(color.r * 0.85, color.g * 0.85, color.b * 0.85, 1)
    end
    c.fill:SetWidth(math.max(width * hp, 0.1))
    c.fill:SetShown(hp > 0)
    local heal = (set.heals ~= false and data.heal and hp > 0) and math.min(data.heal, 1 - hp) or 0
    c.heal:SetWidth(math.max(width * heal, 0.1))
    c.heal:SetShown(heal > 0)

    -- name and health text
    local name = data.name
    local limit = set.nameLength or 0
    if limit > 0 then name = name:sub(1, limit) end
    ns.SetFont(c.name, textSize)
    ns.SetFont(c.status, textSize)
    c.name:SetText(name)
    c.name:ClearAllPoints()
    c.status:ClearAllPoints()
    if row then
        c.name:SetJustifyH("LEFT")
        c.status:SetJustifyH("RIGHT")
        c.status:SetPoint("RIGHT", -5, 0)
        c.name:SetPoint("LEFT", 5, 0)
        c.name:SetPoint("RIGHT", c.status, "LEFT", -4, 0)
    else
        c.name:SetJustifyH("CENTER")
        c.status:SetJustifyH("CENTER")
        -- in the middle when there is no text under it (see UpdateHealth in Group.lua)
        local y = (data.dead or data.offline or set.healthText ~= "none") and 5 or 0
        c.name:SetPoint("LEFT", 3, y)
        c.name:SetPoint("RIGHT", -3, y)
        c.status:SetPoint("BOTTOM", 0, 4)
    end
    if data.dead or data.offline then
        c.status:SetText(data.dead and "Dead" or "Offline")
        c.status:SetTextColor(0.8, 0.4, 0.4)
        c.name:SetTextColor(0.6, 0.6, 0.6)
    else
        local text = ""
        if set.healthText == "percent" then
            text = ("%d%%"):format(hp * 100 + 0.5)
        elseif set.healthText == "current" then
            text = Short(FAKE_MAX * hp)
        elseif set.healthText == "deficit" and hp < 1 then
            text = "-" .. Short(FAKE_MAX * (1 - hp))
        end
        c.status:SetText(text)
        c.status:SetTextColor(1, 1, 1)
        if set.nameColor == "class" then
            c.name:SetTextColor(color.r, color.g, color.b)
        else
            c.name:SetTextColor(1, 1, 1)
        end
    end

    -- power
    local showPower = not data.dead and not data.offline
        and (set.power == "all" or (set.power == "mana" and CLASS_MANA[data.class]))
    c.power:SetShown(showPower and true or false)
    c.powerBack:SetShown(showPower and true or false)
    if showPower then
        if CLASS_MANA[data.class] then
            c.power:SetColorTexture(0.27, 0.56, 1, 1)
        elseif data.class == "ROGUE" then
            c.power:SetColorTexture(1, 0.9, 0.2, 1)
        else
            c.power:SetColorTexture(0.9, 0.15, 0.15, 1)
        end
        c.power:SetWidth(math.max(width * (data.power or 0.5), 0.1))
    end

    -- aggro: a rim outside the cell where there is room, inside it where cells touch (as on the real frames)
    local aggro = data.aggro and set.aggro ~= false and true or false
    local tight = (set.gap or 0) < 4
    c.rim:SetShown(aggro and not tight)
    if not c.rimInside then
        c.rimInside = {}
        for n = 1, 4 do
            local t = c:CreateTexture(nil, "OVERLAY", nil, 5)
            t:SetColorTexture(0.95, 0.12, 0.12, 1)
            c.rimInside[n] = t
        end
        c.rimInside[1]:SetPoint("TOPLEFT")
        c.rimInside[1]:SetPoint("TOPRIGHT")
        c.rimInside[1]:SetHeight(2)
        c.rimInside[2]:SetPoint("BOTTOMLEFT")
        c.rimInside[2]:SetPoint("BOTTOMRIGHT")
        c.rimInside[2]:SetHeight(2)
        c.rimInside[3]:SetPoint("TOPLEFT")
        c.rimInside[3]:SetPoint("BOTTOMLEFT")
        c.rimInside[3]:SetWidth(2)
        c.rimInside[4]:SetPoint("TOPRIGHT")
        c.rimInside[4]:SetPoint("BOTTOMRIGHT")
        c.rimInside[4]:SetWidth(2)
    end
    for _, t in ipairs(c.rimInside) do t:SetShown(aggro and tight) end
    c.strip:SetShown(data.cast and set.castStrip ~= false and true or false)

    -- auras
    for _, icon in ipairs(c.icons) do
        icon.tex:Hide()
        icon.edge:Hide()
        icon.count:Hide()
    end
    for _, holder in ipairs(c.rows) do holder:Hide() end
    local used = 0
    local dispel = data.dispel or 0
    if dispel > 0 and set.dispelTint ~= false then
        c.tint:SetColorTexture(0.35, 0.47, 1, set.tintStrength or 0.5)
        c.tint:Show()
    else
        c.tint:Hide()
    end
    if dispel > 0 then
        local big = math.max(12, set.dispelSize or 22)
        local size = dispel == 1 and big or math.max(8, math.floor(big / 2 + 0.5))
        used = IconRow(c, used, 1, DISPEL_ICONS, dispel, size, "CENTER", set.stacks ~= false and data.stack or nil)
    end
    local debuffs = math.min(data.debuffs or 0, set.debuffCount or 0)
    local lift = (set.power == "mana" or set.power == "all") and 4 or 0 -- clear of the power bar, as on the real frames
    used = IconRow(c, used, 2, DEBUFF_ICONS, debuffs, set.debuffSize or 14, set.debuffSpot,
        (dispel == 0 and set.stacks ~= false) and data.stack or nil, lift)
    local buffs = math.min(data.buffs or 0, set.buffCount or 0)
    IconRow(c, used, 3, BUFF_ICONS, buffs, set.buffSize or 12, set.buffSpot, nil, lift)
end

local function DrawPreview()
    if not preview.shown then
        if preview.frame then preview.frame:Hide() end
        return
    end
    local set = S()
    local anchor = _G["KeebUIAnchor_" .. kind]
    local f = preview.frame
    if not f then
        f = CreateFrame("Frame", "KeebUIGroupPreview", UIParent)
        f:SetFrameStrata("HIGH")
        f.back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f.back:SetPoint("TOPLEFT", -6, 22)
        f.back:SetPoint("BOTTOMRIGHT", 6, -6)
        f.back:SetColorTexture(0.03, 0.04, 0.03, 0.9)
        f.label = ns.Text(f, 12, "LEFT")
        f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 5)
        f.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        preview.frame = f
    end

    local width, height, textSize, gap, count, row
    if kind == "party" then
        width, height, textSize, gap = set.width, set.height, set.text, set.gap
        count, row = set.showPlayer and 5 or 4, true
    else
        width, height, textSize = set["w" .. editSize], set["h" .. editSize], set["t" .. editSize]
        gap, count = set.gap, tonumber(editSize)
    end

    local total, totalHeight
    for i = 1, count do
        local c = preview.cells[i]
        if not c then
            c = NewPreviewCell(f)
            preview.cells[i] = c
        end
        local data = FAKE[(i - 1) % #FAKE + 1]
        DrawCell(c, set, row, width, height, textSize, data)
        c:ClearAllPoints()
        if kind == "party" then
            if set.growUp then
                c:SetPoint("BOTTOMLEFT", 0, (i - 1) * (height + gap))
            else
                c:SetPoint("TOPLEFT", 0, -(i - 1) * (height + gap))
            end
        else
            local group, member = math.floor((i - 1) / 5), (i - 1) % 5
            if set.orientation == "ROWS" then
                c:SetPoint("TOPLEFT", member * (width + gap), -group * (height + gap))
            else
                c:SetPoint("TOPLEFT", group * (width + gap), -member * (height + gap))
            end
        end
        c:Show()
    end
    for i = count + 1, #preview.cells do preview.cells[i]:Hide() end

    if kind == "party" then
        total, totalHeight = width, count * height + (count - 1) * gap
    else
        local groups = math.ceil(count / 5)
        if set.orientation == "ROWS" then
            total, totalHeight = 5 * width + 4 * gap, groups * height + (groups - 1) * gap
        else
            total, totalHeight = groups * width + (groups - 1) * gap, 5 * height + 4 * gap
        end
    end
    f:SetSize(total, totalHeight)
    f:ClearAllPoints()
    if anchor then
        f:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
        local up = kind == "party" and set.growUp
        f:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", anchor, up and "BOTTOMLEFT" or "TOPLEFT")
    else
        f:SetScale(ns.db.scale or 1)
        f:SetPoint("CENTER", UIParent, "CENTER", -320, 80)
    end
    f.label:SetText(kind == "party" and "Preview: party" or ("Preview: " .. editSize .. "-player raid"))
    f:Show()
end
local SafeDrawPreview = ns.Safe("frame preview", DrawPreview)

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local function Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function TextButton(parent, width, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 96, 22)
    local edge = Flat(b, 0, 0, 0, 1, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.fill = Flat(b, 0.16, 0.18, 0.16, 1, "BORDER")
    b.fill:SetAllPoints()
    local shine = b:CreateTexture(nil, "HIGHLIGHT")
    shine:SetAllPoints()
    shine:SetColorTexture(1, 1, 1, 0.08)
    b.label = ns.Text(b, 13, "CENTER")
    b.label:SetPoint("CENTER")
    if text then b.label:SetText(text) end
    return b
end

local function Lit(b, on)
    if on then
        -- dark text on gold: no outline or shadow, or it smears
        b.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        b.label:SetFont(ns.FONT, 13, "")
        b.label:SetTextColor(0.08, 0.09, 0.08)
        b.label:SetShadowColor(0, 0, 0, 0)
    else
        b.fill:SetColorTexture(0.16, 0.18, 0.16, 1)
        b.label:SetFont(ns.FONT, 13, "OUTLINE")
        b.label:SetTextColor(0.7, 0.72, 0.7)
        b.label:SetShadowColor(0, 0, 0, 1)
    end
end

-- a strip of choices, exactly one lit
local function Pick(parent, choices, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    local x, buttons = 0, {}
    for _, choice in ipairs(choices) do
        local b = TextButton(holder, 10, choice[2])
        b:SetWidth((b.label:GetStringWidth() or 30) + 18)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 2
        b.value = choice[1]
        b:SetScript("OnClick", function() set(choice[1]) end)
        buttons[#buttons + 1] = b
    end
    holder:SetSize(math.max(x - 2, 1), 22)
    function holder:Paint()
        local now = get()
        for _, b in ipairs(buttons) do Lit(b, b.value == now) end
    end
    return holder
end

local function Switch(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 18)
    local edge = Flat(b, 0, 0, 0, 1, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local track = Flat(b, 0.22, 0.25, 0.23, 1, "BORDER")
    track:SetAllPoints()
    local knob = Flat(b, 0.8, 0.82, 0.8, 1, "ARTWORK")
    knob:SetSize(14, 14)
    function b:Paint()
        local on = get() and true or false
        knob:ClearAllPoints()
        if on then
            track:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            knob:SetColorTexture(0.08, 0.09, 0.08, 1)
            knob:SetPoint("RIGHT", -2, 0)
        else
            track:SetColorTexture(0.22, 0.25, 0.23, 1)
            knob:SetColorTexture(0.8, 0.82, 0.8, 1)
            knob:SetPoint("LEFT", 2, 0)
        end
    end
    b:SetScript("OnClick", function() set(not get()) end)
    return b
end

local function Slider(parent, low, high, step, percent, get, set)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(170, 16)
    s:SetMinMaxValues(low, high)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = Flat(s, 1, 1, 1, 0.15, "BACKGROUND")
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    thumb:SetSize(8, 16)
    s:SetThumbTexture(thumb)
    local value = ns.Text(s, 13, "RIGHT")
    value:SetPoint("RIGHT", s, "LEFT", -8, 0)
    local function Show(v)
        if percent then value:SetText(("%d%%"):format(v * 100 + 0.5)) else value:SetText(("%d"):format(v + 0.5)) end
    end
    local painting = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if painting then return end
        if math.abs((get() or 0) - v) < step / 2 then return end
        set(v)
    end)
    function s:Paint()
        painting = true
        local v = get() or low
        self:SetValue(v)
        Show(v)
        painting = false
    end
    return s
end

-- A picture of a cell with a square for each place an icon row can go:
-- eight inside it, one beside it on each side. The chosen one is gold and
-- named in words to the left.
local SPOTS = {
    { "OUT_LEFT", -62, 0, "Beside it, left" },
    { "TOPLEFT", -34, 13, "Top left" }, { "TOP", 0, 13, "Top" }, { "TOPRIGHT", 34, 13, "Top right" },
    { "LEFT", -34, 0, "Left" }, { "RIGHT", 34, 0, "Right" },
    { "BOTTOMLEFT", -34, -13, "Bottom left" }, { "BOTTOM", 0, -13, "Bottom" }, { "BOTTOMRIGHT", 34, -13, "Bottom right" },
    { "OUT_RIGHT", 62, 0, "Beside it, right" },
}
local function SpotPicker(parent, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(140, 36)
    local cellEdge = Flat(holder, 0, 0, 0, 1, "BACKGROUND")
    cellEdge:SetSize(92, 36)
    cellEdge:SetPoint("CENTER")
    local cell = Flat(holder, 0.24, 0.27, 0.24, 1, "BORDER")
    cell:SetPoint("TOPLEFT", cellEdge, 1, -1)
    cell:SetPoint("BOTTOMRIGHT", cellEdge, -1, 1)
    local named = ns.Text(holder, 12, "RIGHT")
    named:SetPoint("RIGHT", holder, "LEFT", -10, 0)
    named:SetTextColor(0.7, 0.72, 0.7)
    local dots = {}
    for _, spot in ipairs(SPOTS) do
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(16, 12)
        b:SetPoint("CENTER", holder, "CENTER", spot[2], spot[3])
        b.rim = Flat(b, 0, 0, 0, 1, "ARTWORK")
        b.rim:SetSize(12, 9)
        b.rim:SetPoint("CENTER")
        b.dot = b:CreateTexture(nil, "OVERLAY")
        b.dot:SetSize(10, 7)
        b.dot:SetPoint("CENTER")
        local shine = b:CreateTexture(nil, "HIGHLIGHT")
        shine:SetAllPoints(b.rim)
        shine:SetColorTexture(1, 1, 1, 0.35)
        b.value, b.words = spot[1], spot[4]
        b:SetScript("OnClick", function() set(spot[1]) end)
        dots[#dots + 1] = b
    end
    function holder:Paint()
        local now = get()
        for _, b in ipairs(dots) do
            if b.value == now then
                b.dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
                named:SetText(b.words)
            else
                b.dot:SetColorTexture(0.5, 0.53, 0.5, 1)
            end
        end
    end
    return holder
end

---------------------------------------------------------------------------
-- What is on each tab. key may be a function (the raid sizes share one set
-- of sliders, pointed at whichever size is being edited).
---------------------------------------------------------------------------
local function Rows(forKind, forTab)
    local raid = forKind == "raid"
    if forTab == "Layout" then
        if raid then
            return {
                { "Cell width", "For the raid size chosen above", "slider", function() return "w" .. editSize end, 40, 220, 2 },
                { "Cell height", nil, "slider", function() return "h" .. editSize end, 18, 90, 1 },
                { "Text size", nil, "slider", function() return "t" .. editSize end, 8, 20, 1 },
                { "Gap between cells", "All raid sizes", "slider", "gap", 0, 10, 1 },
                { "Groups run", "Each group as a column, or as a row", "pick", "orientation",
                    { { "COLUMNS", "Down" }, { "ROWS", "Across" } } },
                { "Sort by", "By class and by name ignore raid groups", "pick", "sort",
                    { { "GROUP", "Group" }, { "CLASS", "Class" }, { "NAME", "Name" } } },
                { "Tanks first", "In each group: tanks, then healers, then the rest, by role", "toggle", "tanksFirst" },
            }
        end
        return {
            { "Row width", nil, "slider", "width", 80, 320, 2 },
            { "Row height", nil, "slider", "height", 18, 70, 1 },
            { "Text size", nil, "slider", "text", 8, 20, 1 },
            { "Gap between rows", nil, "slider", "gap", 0, 12, 1 },
            { "Grows", "From its anchor", "pick", "growUp", { { true, "Up" }, { false, "Down" } } },
            { "Show yourself", "As the first row", "toggle", "showPlayer" },
            { "Tank on top", "By role: tank, then healer, then the rest", "toggle", "tanksFirst" },
        }
    elseif forTab == "Cell" then
        return {
            { "Health text", "Missing shows how much health is gone", "pick", "healthText",
                { { "none", "None" }, { "percent", "Percent" }, { "deficit", "Missing" }, { "current", "Current" } } },
            { "Name colour", nil, "pick", "nameColor", { { "white", "White" }, { "class", "Class" } } },
            { "Name length", "Letters shown; 0 shows the whole name", "slider", "nameLength", 0, 12, 1 },
            { "Power bar", "A thin bar along the bottom", "pick", "power",
                { { "none", "None" }, { "mana", "Mana users" }, { "all", "Everyone" } } },
        }
    elseif forTab == "Auras" then
        return {
            { "Removable debuff size", "One alone is this big; two or more are half", "slider", "dispelSize", 12, 44, 1 },
            { "Tint the cell", "While they have something you can remove", "toggle", "dispelTint" },
            { "Tint strength", nil, "slider", "tintStrength", 0.15, 0.9, 0.05, true },
            { "Stack numbers", "On debuffs that stack", "toggle", "stacks" },
            { "Other debuffs shown", "Ones you cannot remove", "slider", "debuffCount", 0, 6, 1 },
            { "Other debuff size", nil, "slider", "debuffSize", 8, 30, 1 },
            { "Other debuffs go", nil, "spot", "debuffSpot" },
            { "Your buffs shown", "Buffs you cast on them", "slider", "buffCount", 0, 6, 1 },
            { "Longest buff shown", "In seconds. Hides blessings and other long buffs; 0 shows all", "slider", "buffMaxSeconds", 0, 600, 15 },
            { "Buff size", nil, "slider", "buffSize", 8, 30, 1 },
            { "Your buffs go", nil, "spot", "buffSpot" },
        }
    end
    return {
        { "Bar colour", "Dark makes missing health stand out", "pick", "barColor",
            { { "class", "Class" }, { "health", "By health" }, { "dark", "Dark" } } },
        { "Out of range", "How visible a far-away member stays", "slider", "rangeAlpha", 0.15, 1, 0.05, true },
        { "Incoming heals", "A green stretch ahead of the health bar", "toggle", "heals" },
        { "Aggro rim", "Red or orange outline when a mob is on them", "toggle", "aggro" },
        { "Incoming cast strip", "Yellow strip while an enemy casts at them", "toggle", "castStrip" },
    }
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Create()
    local f = CreateFrame("Frame", "KeebUIGroupOptions", UIParent)
    f:SetSize(WIDTH, 116 + 6 * ROW + 96)
    f:SetPoint("TOP", UIParent, "CENTER", 260, 300)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- keep the top edge where it was dropped, so a taller tab grows downward
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        self.placedByHand = true
    end)
    f:Hide()
    tinsert(UISpecialFrames, "KeebUIGroupOptions") -- Escape closes it
    local edge = Flat(f, 0, 0, 0, 1, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local back = Flat(f, 0.08, 0.09, 0.08, 0.97, "BORDER")
    back:SetAllPoints()

    local title = ns.Text(f, 16, "LEFT")
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText("Raid and party frames")
    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local closeShine = close:CreateTexture(nil, "HIGHLIGHT")
    closeShine:SetAllPoints()
    closeShine:SetColorTexture(1, 1, 1, 0.1)
    local cross = ns.Text(close, 16, "CENTER")
    cross:SetPoint("CENTER", 0, 1)
    cross:SetTextColor(0.7, 0.72, 0.7)
    cross:SetText("x")
    close:SetScript("OnClick", function() f:Hide() end)

    local painters = {} -- everything with a Paint method that is always on screen

    -- which frames, and which raid size
    local kindPick = Pick(f, { { "raid", "Raid" }, { "party", "Party" } },
        function() return kind end,
        function(v)
            kind = v
            Refresh()
        end)
    kindPick:SetPoint("TOPLEFT", PAD, -44)
    painters[#painters + 1] = kindPick
    local sizeLabel = ns.Text(f, 12, "RIGHT")
    sizeLabel:SetTextColor(0.6, 0.63, 0.6)
    sizeLabel:SetText("Raid size")
    local sizePick = Pick(f, { { "10", "10" }, { "20", "20" }, { "40", "40" } },
        function() return editSize end,
        function(v)
            editSize = v
            Refresh()
        end)
    sizePick:SetPoint("TOPRIGHT", -PAD, -44)
    sizeLabel:SetPoint("RIGHT", sizePick, "LEFT", -8, 0)
    painters[#painters + 1] = sizePick

    -- tabs
    local tabPick = Pick(f, { { "Layout", "Layout" }, { "Cell", "Cell" }, { "Auras", "Auras" }, { "Health", "Health" },
        { "Clicks", "Clicks" } },
        function() return tab end,
        function(v)
            tab = v
            Refresh()
        end)
    tabPick:SetPoint("TOPLEFT", PAD, -78)
    painters[#painters + 1] = tabPick
    local rule = Flat(f, 1, 1, 1, 0.08, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", PAD, -108)
    rule:SetPoint("TOPRIGHT", -PAD, -108)

    -- footer
    local own = Switch(f, function() return ns.FramesPerCharacter() end, function(on)
        ns.SetFramesPerCharacter(on)
        dirty = true
        Refresh()
    end)
    own:SetPoint("BOTTOMLEFT", PAD, 42)
    painters[#painters + 1] = own
    local ownLabel = ns.Text(f, 13, "LEFT")
    ownLabel:SetPoint("LEFT", own, "RIGHT", 8, 0)
    ownLabel:SetText("This character has its own settings")
    local show = Switch(f, function() return preview.shown end, function(on)
        preview.shown = on
        Refresh()
    end)
    show:SetPoint("BOTTOMLEFT", PAD, 14)
    painters[#painters + 1] = show
    local showLabel = ns.Text(f, 13, "LEFT")
    showLabel:SetPoint("LEFT", show, "RIGHT", 8, 0)
    showLabel:SetText("Preview")

    local reload = TextButton(f, 96, "Reload UI")
    reload:SetPoint("BOTTOMRIGHT", -PAD, 12)
    reload:SetScript("OnClick", ReloadUI)
    local note = ns.Text(f, 12, "RIGHT")
    note:SetPoint("RIGHT", reload, "LEFT", -10, 0)
    note:SetTextColor(0.6, 0.63, 0.6)
    local defaults = TextButton(f, 84, "Defaults")
    defaults:SetPoint("BOTTOMRIGHT", -PAD, 42)
    defaults:SetScript("OnClick", function()
        if tab == "Clicks" then
            -- left click targets, right click opens the menu, nothing else bound
            local casts = ns.ClickCasts()
            wipe(casts)
            casts["1"], casts["2"] = "target", "menu"
        else
            wipe(S()) -- back to the built-in values, for the frames being edited
        end
        dirty = true
        Refresh()
    end)

    -- after a setting changes: the reload prompt and the preview
    local function Changed()
        note:SetText(dirty and "Reload to apply to the real frames" or "")
        reload:SetShown(dirty)
        SafeDrawPreview()
    end

    -- pages: one per kind and tab, made the first time they are opened
    local pages = {}
    -- Click casting: one row per mouse button and modifier. Type a spell name,
    -- or press Target / Menu; an empty row does nothing. One set of bindings
    -- serves both party and raid frames.
    local function ClickPage()
        local LINE = 27
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", PAD, -116)
        p:SetPoint("BOTTOMRIGHT", -PAD, 86)
        p.controls = {}
        local about = ns.Text(p, 12, "LEFT")
        about:SetPoint("TOPLEFT", 0, -2)
        about:SetPoint("RIGHT", 0, 0)
        about:SetWordWrap(true)
        about:SetTextColor(0.55, 0.58, 0.55)
        about:SetText("What each click does on party and raid frames alike. Type a spell name, or press Target or Menu. An empty row does nothing. Your own target frame is not affected.")

        local casts = ns.ClickCasts()
        local y = -40
        for b, button in ipairs(ns.CLICK_BUTTONS) do
            for _, modifier in ipairs(ns.CLICK_MODS) do
                local key = modifier[1] .. button[1]
                local label = ns.Text(p, 13, "LEFT")
                label:SetPoint("TOPLEFT", 0, y - 4)
                label:SetText(modifier[2] .. button[2])

                local box = CreateFrame("EditBox", nil, p)
                box:SetSize(230, 21)
                box:SetPoint("TOPLEFT", 130, y)
                box:SetAutoFocus(false)
                box:SetFont(ns.FONT, 13, "OUTLINE")
                box:SetTextInsets(6, 6, 0, 0)
                box:SetMaxLetters(60)
                local boxEdge = Flat(box, 0, 0, 0, 1, "BACKGROUND")
                boxEdge:SetPoint("TOPLEFT", -1, 1)
                boxEdge:SetPoint("BOTTOMRIGHT", 1, -1)
                local boxFill = Flat(box, 0.13, 0.15, 0.13, 1, "BORDER")
                boxFill:SetAllPoints()

                local row = {}
                function row:Paint()
                    local value = casts[key]
                    if value == "target" or value == "menu" then
                        box:SetText(value == "target" and "Target" or "Menu")
                        box:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                    else
                        box:SetText(value or "")
                        box:SetTextColor(1, 1, 1)
                    end
                end
                local function Set(text)
                    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    local lower = text:lower()
                    local value = text
                    if text == "" then
                        value = nil
                    elseif lower == "target" or lower == "menu" then
                        value = lower
                    end
                    if casts[key] ~= value then
                        casts[key] = value
                        dirty = true
                    end
                    row:Paint()
                    Changed()
                end
                box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                box:SetScript("OnEscapePressed", function(self)
                    row:Paint() -- put back what was there
                    self:ClearFocus()
                end)
                box:SetScript("OnEditFocusGained", function(self)
                    self:SetTextColor(1, 1, 1)
                    self:HighlightText()
                end)
                box:SetScript("OnEditFocusLost", function(self)
                    self:HighlightText(0, 0)
                    Set(self:GetText())
                end)
                p:HookScript("OnHide", function() box:ClearFocus() end)

                local target = TextButton(p, 60, "Target")
                target:SetPoint("LEFT", box, "RIGHT", 10, 0)
                target:SetScript("OnClick", function()
                    box:ClearFocus()
                    Set("target")
                end)
                local menu = TextButton(p, 54, "Menu")
                menu:SetPoint("LEFT", target, "RIGHT", 5, 0)
                menu:SetScript("OnClick", function()
                    box:ClearFocus()
                    Set("menu")
                end)
                local clear = TextButton(p, 22, "x")
                clear:SetPoint("LEFT", menu, "RIGHT", 5, 0)
                clear:SetScript("OnClick", function()
                    box:ClearFocus()
                    Set("")
                end)

                p.controls[#p.controls + 1] = row
                y = y - LINE
            end
            y = y - 8 -- a little air between the Left, Right and Middle blocks
        end
        p.height = -y + 4
        return p
    end

    local function Page(forKind, forTab)
        if forTab == "Clicks" then
            pages.Clicks = pages.Clicks or ClickPage()
            return pages.Clicks
        end
        local id = forKind .. forTab
        if pages[id] then return pages[id] end
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", PAD, -116)
        p:SetPoint("BOTTOMRIGHT", -PAD, 86)
        p.controls = {}
        for n, row in ipairs(Rows(forKind, forTab)) do
            local y = -(n - 1) * ROW
            local label = ns.Text(p, 14, "LEFT")
            label:SetPoint("TOPLEFT", 0, y - (row[2] and 3 or 10))
            label:SetText(row[1])
            if row[2] then
                local sub = ns.Text(p, 12, "LEFT")
                sub:SetPoint("TOPLEFT", 0, y - 20)
                sub:SetTextColor(0.55, 0.58, 0.55)
                sub:SetText(row[2])
            end
            local key = row[4]
            local function Key() return type(key) == "function" and key() or key end
            local function get() return ns.FrameSettings(forKind)[Key()] end
            local control
            local function set(v)
                ns.FrameSettings(forKind)[Key()] = v
                dirty = true
                -- Only this control and the preview are redrawn. (Redrawing the
                -- whole page here used to hide and re-show it, which made the
                -- game drop a slider in the middle of a drag.)
                if control and row[3] ~= "slider" then control:Paint() end
                Changed()
            end
            if row[3] == "slider" then
                control = Slider(p, row[5], row[6], row[7], row[8], get, set)
            elseif row[3] == "pick" then
                control = Pick(p, row[5], get, set)
            elseif row[3] == "toggle" then
                control = Switch(p, function() return get() ~= false and get() ~= nil end, set)
            else
                control = SpotPicker(p, get, set)
            end
            control:SetPoint("RIGHT", p, "TOPRIGHT", 0, y - ROW / 2 + 2)
            p.controls[#p.controls + 1] = control
        end
        pages[id] = p
        return p
    end

    Refresh = function()
        for _, painter in ipairs(painters) do painter:Paint() end
        sizePick:SetShown(kind == "raid" and tab ~= "Clicks")
        sizeLabel:SetShown(kind == "raid" and tab ~= "Clicks")
        local p = Page(kind, tab)
        for _, other in pairs(pages) do
            if other ~= p then other:Hide() end
        end
        for _, control in ipairs(p.controls) do control:Paint() end
        p:Show()
        f:SetHeight(116 + (p.height or math.max(#p.controls, 6) * ROW) + 96)
        note:SetText(dirty and "Reload to apply to the real frames" or "")
        reload:SetShown(dirty)
        SafeDrawPreview()

        -- Until you have dragged the window yourself, it stands beside the
        -- preview rather than on top of it.
        local shown = preview.frame
        if not f.placedByHand and preview.shown and shown and shown:IsShown() then
            local ratio = shown:GetEffectiveScale() / f:GetEffectiveScale()
            local left, right, top = shown:GetLeft(), shown:GetRight(), shown:GetTop()
            if left and right and top then
                left, right, top = left * ratio, right * ratio, top * ratio
                local screen = UIParent:GetWidth() * UIParent:GetEffectiveScale() / f:GetEffectiveScale()
                local screenTop = UIParent:GetHeight() * UIParent:GetEffectiveScale() / f:GetEffectiveScale()
                local x
                if right + 24 + WIDTH <= screen then
                    x = right + 24
                elseif left - 24 - WIDTH >= 0 then
                    x = left - 24 - WIDTH
                end
                if x then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, math.min(screenTop - 20, math.max(top + 30, f:GetHeight() + 20)))
                end
            end
        end
    end

    f:SetScript("OnShow", function()
        preview.shown = true
        Refresh()
    end)
    f:SetScript("OnHide", function()
        preview.shown = false
        SafeDrawPreview()
    end)
    return f
end

function ns.ToggleFrameOptions()
    if not window then
        local ok, made = pcall(Create)
        if not ok then
            ns.LogError("frame settings window", made)
            ns.Print("the frame settings window could not be opened; /keebui errors has the reason.")
            return
        end
        window = made
    end
    window:SetShown(not window:IsShown())
end

-- "/keebui click": the same window, opened on the Clicks tab.
function ns.ToggleClickCast()
    if window and window:IsShown() and tab == "Clicks" then
        window:Hide()
        return
    end
    tab = "Clicks"
    if window and window:IsShown() then
        Refresh()
    else
        ns.ToggleFrameOptions()
    end
end
