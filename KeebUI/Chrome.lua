-- KeebUI chrome: the small things around the edges.
--   * a slim flat experience bar under the action bars
--   * flat menu (micro) buttons
--   * a quieter quest tracker: no header bar until you hover it
--   * the cast bar's easy-to-read font across the rest of the game

local ADDON, ns = ...
local Clean = ns.Clean

---------------------------------------------------------------------------
-- Experience bar
---------------------------------------------------------------------------
local function InitXP()
    local anchor = ns.Anchor("xp", "XP bar", ns.STACK_WIDTH or 573, 7, 0, 8)
    local bar = ns.Bar(anchor)
    ns.Edge(bar)
    bar:SetAllPoints()
    bar:SetStatusBarColor(0.55, 0.38, 0.85)

    -- rested experience: a dimmer stretch ahead of the fill
    local rested = bar:CreateTexture(nil, "BORDER")
    rested:SetColorTexture(0.3, 0.5, 0.9, 0.45)
    rested:SetPoint("TOPLEFT")
    rested:SetPoint("BOTTOMLEFT")
    rested:Hide()

    -- hover label: its own small dark plate drawn above everything, so the
    -- action buttons never cover it
    local tip = CreateFrame("Frame", nil, bar)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetPoint("BOTTOM", bar, "TOP", 0, 6)
    tip:SetHeight(24)
    ns.Edge(tip)
    local plate = tip:CreateTexture(nil, "BACKGROUND", nil, -7)
    plate:SetAllPoints()
    plate:SetColorTexture(0.05, 0.05, 0.05, 0.92)
    tip:Hide()
    local label = ns.Text(tip, 14, "CENTER")
    label:SetPoint("CENTER")
    local text = {
        Show = function() tip:Show() end,
        Hide = function() tip:Hide() end,
        SetText = function(_, value)
            label:SetText(value)
            tip:SetWidth((label:GetStringWidth() or 200) + 20)
        end,
    }
    bar:EnableMouse(true)
    -- the bar is thin, so the area that counts as hovering it reaches from the
    -- bottom of the screen up to the buttons
    bar:SetHitRectInsets(0, 0, -5, -5)
    bar:SetScript("OnEnter", function() text:Show() end)
    bar:SetScript("OnLeave", function() text:Hide() end)

    local MAX_LEVEL = 60
    local XP_COLOR = { 0.55, 0.38, 0.85 }
    local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    local STANDING_COLOR = {
        { 0.8, 0.2, 0.2 }, { 0.8, 0.2, 0.2 }, { 0.85, 0.5, 0.2 }, { 0.85, 0.75, 0.2 },
        { 0.2, 0.7, 0.25 }, { 0.2, 0.7, 0.25 }, { 0.2, 0.7, 0.25 }, { 0.25, 0.75, 0.8 },
    }

    -- The reputation you have set to "show as experience bar", if any:
    -- name, standing (1-8), progress into the current standing, and its size.
    local function Watched()
        if C_Reputation and C_Reputation.GetWatchedFactionData then
            local ok, data = pcall(C_Reputation.GetWatchedFactionData)
            if ok and type(data) == "table" and data.name and data.name ~= "" then
                local low = data.currentReactionThreshold or 0
                local high = data.nextReactionThreshold or low
                return data.name, data.reaction, (data.currentStanding or low) - low, high - low
            end
        end
        if GetWatchedFactionInfo then
            local name, standing, low, high, value = GetWatchedFactionInfo()
            if name then return name, standing, (value or 0) - (low or 0), (high or 0) - (low or 0) end
        end
    end

    local function Update()
        local xp, max = Clean(UnitXP("player")), Clean(UnitXPMax("player"))
        local level = Clean(UnitLevel("player")) or 0
        local capped = level >= MAX_LEVEL or (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
        if capped or not xp or not max or max <= 0 then
            -- at the level cap there is no experience to show: the bar goes
            -- away, unless a reputation is being tracked, which takes its place
            local name, standing, value, size = Watched()
            name, standing, value, size = Clean(name), Clean(standing), Clean(value), Clean(size)
            if not capped or not name or not value or not size then
                bar:Hide()
                return
            end
            rested:Hide()
            local c = STANDING_COLOR[standing or 4] or STANDING_COLOR[4]
            bar:SetStatusBarColor(c[1], c[2], c[3])
            bar:Show()
            if size <= 0 then -- top of the last standing: show it full
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(1)
                text:SetText(("%s   %s"):format(name, STANDING[standing or 4] or ""))
            else
                bar:SetMinMaxValues(0, size)
                bar:SetValue(value)
                text:SetText(("%s   %s   %s / %s"):format(name, STANDING[standing or 4] or "",
                    BreakUpLargeNumbers(value), BreakUpLargeNumbers(size)))
            end
            return
        end
        bar:SetStatusBarColor(XP_COLOR[1], XP_COLOR[2], XP_COLOR[3])
        bar:Show()
        bar:SetMinMaxValues(0, max)
        bar:SetValue(xp)
        local rest = Clean(GetXPExhaustion()) or 0
        if rest > 0 then
            rested:SetWidth(math.max(1, math.min(1, (xp + rest) / max) * bar:GetWidth()))
            rested:Show()
        else
            rested:Hide()
        end
        local line = ("Level %d   %s / %s   %d%%"):format(level,
            BreakUpLargeNumbers(xp), BreakUpLargeNumbers(max), xp / max * 100)
        if rest > 0 then line = line .. ("   rested +%s"):format(BreakUpLargeNumbers(rest)) end
        text:SetText(line)
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
        "UPDATE_FACTION" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", ns.Safe("xp bar", Update))
    ns.Safe("xp bar", Update)()

    -- the built-in bars stay where they are, just invisible
    for _, name in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer" }) do
        local frame = _G[name]
        if frame then
            frame:SetAlpha(0)
            if frame.EnableMouse then frame:EnableMouse(false) end
        end
    end
end

---------------------------------------------------------------------------
-- Menu buttons: drop the raised plate, keep the glyph, frame it flat
---------------------------------------------------------------------------
local MICRO = {
    "CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton",
    "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton",
    "LFDMicroButton", "LFGMicroButton", "CollectionsMicroButton", "EJMicroButton", "StoreMicroButton",
    "MainMenuMicroButton", "HelpMicroButton", "HousingMicroButton", "WorldMapMicroButton",
}
local PLATE = { "Background", "PushedBackground", "FlashBorder", "Shadow", "PushedShadow", "Border", "Backdrop" }
local microDone = setmetatable({}, { __mode = "k" })

local function FitGlyph(texture, box)
    if not texture or not texture.SetTexCoord then return end
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
end

local function SkinMicro(button)
    for _, key in ipairs(PLATE) do
        local art = button[key]
        if art and art.SetAlpha then art:SetAlpha(0) end
    end
    local box = microDone[button]
    if not box then
        box = CreateFrame("Frame", nil, button)
        box:SetPoint("TOPLEFT", 2, -2)
        box:SetPoint("BOTTOMRIGHT", -2, 2)
        box:SetFrameLevel(button:GetFrameLevel())
        local edge = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        edge:SetColorTexture(0, 0, 0, 1)
        edge:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
        local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)
        bg:SetAllPoints(box)
        local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
        if highlight and highlight.SetColorTexture then
            highlight:SetColorTexture(1, 1, 1, 0.12)
            highlight:ClearAllPoints()
            highlight:SetAllPoints(box)
        end
        microDone[button] = box
    end
    if button.GetNormalTexture then FitGlyph(button:GetNormalTexture(), box) end
    if button.GetPushedTexture then FitGlyph(button:GetPushedTexture(), box) end
    if button.GetDisabledTexture then FitGlyph(button:GetDisabledTexture(), box) end
    if button.Portrait then FitGlyph(button.Portrait, box) end
end

local function InitMicro()
    local pending = false
    local function Run()
        pending = false
        if InCombatLockdown() then return end
        for _, name in ipairs(MICRO) do
            local button = _G[name]
            if button and not (button.IsForbidden and button:IsForbidden()) then
                local ok, err = pcall(SkinMicro, button)
                if not ok then ns.LogError("menu button", err) end
            end
        end
    end
    Run()
    if UpdateMicroButtons then
        -- the game repaints these in bursts; one tidy-up per burst is enough
        hooksecurefunc("UpdateMicroButtons", function()
            if pending then return end
            pending = true
            C_Timer.After(0.1, Run)
        end)
    end
end

---------------------------------------------------------------------------
-- Quest tracker: the big header bar only appears while the mouse is over it
---------------------------------------------------------------------------
local function InitTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    local function Quiet()
        local header = tracker.Header
        if header and header.Background then header.Background:SetAlpha(0) end
        for _, module in ipairs(tracker.modules or {}) do
            local h = module.Header
            if h and h.Background then h.Background:SetAlpha(0) end
        end
        return header
    end

    C_Timer.NewTicker(0.25, ns.Safe("quest tracker", function()
        local header = Quiet()
        if header then header:SetAlpha(tracker:IsMouseOver() and 1 or 0) end
    end))
end

---------------------------------------------------------------------------
-- Font: one readable face for the stock text styles (sizes are kept)
---------------------------------------------------------------------------
local FONT_OBJECTS = {
    "GameFontNormal", "GameFontHighlight", "GameFontDisable",
    "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall",
    "GameFontNormalMed1", "GameFontNormalMed2", "GameFontNormalMed3", "GameFontHighlightMedium",
    "GameFontNormalLarge", "GameFontHighlightLarge", "GameFontNormalHuge",
    "NumberFontNormal", "NumberFontNormalSmall", "NumberFontNormalLarge",
    "ChatFontNormal", "ChatFontSmall",
    "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall",
    "QuestFont", "QuestFontNormalSmall", "QuestTitleFont",
    "ObjectiveFont", "ObjectiveTrackerHeaderFont", "ObjectiveTrackerLineFont",
    "SystemFont_Shadow_Small", "SystemFont_Shadow_Med1", "SystemFont_Shadow_Med2", "SystemFont_Shadow_Large",
    "SystemFont_Small", "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Med3", "SystemFont_Large",
    "FriendsFont_Normal", "FriendsFont_Small", "FriendsFont_Large",
}

local function InitFont()
    for _, name in ipairs(FONT_OBJECTS) do
        local object = _G[name]
        if object and object.GetFont and object.SetFont then
            local _, size, flags = object:GetFont()
            if size and size > 0 then
                pcall(object.SetFont, object, ns.FONT, size, flags or "")
            end
        end
    end
end

-- The bag row is a touch wider than the menu row under it. Edit Mode only
-- sizes it in 10% steps, so it is trimmed here to the same width, and
-- trimmed again whenever the game resets its size.
local BAG_TRIM = 0.95

local function InitBags()
    local bags = BagsBar
    if not bags or not bags.SetScale then return end
    local busy = false
    local function Trim(scale)
        if busy or InCombatLockdown() then return end
        busy = true
        pcall(bags.SetScale, bags, (scale or 1) * BAG_TRIM)
        busy = false
    end
    -- The game resizes the bags from inside its own protected code (Edit
    -- Mode). The trim is done a moment later rather than in the middle of that.
    hooksecurefunc(bags, "SetScale", function(_, scale)
        if busy then return end
        scale = ns.Clean(scale)
        C_Timer.After(0, function() Trim(scale) end)
    end)
    Trim(bags:GetScale())
end

---------------------------------------------------------------------------
-- Equipment-set gear in bags: anything that belongs to one of your saved
-- equipment sets gets a bright teal frame and a small corner tab, so it is
-- obvious what not to sell or delete. Works on the game's own bags, and on
-- Bagnon's if that is installed.
---------------------------------------------------------------------------
local SET_COLOR = { 0.2, 1, 0.8 }

local function InitSetGlow()
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs) then return end

    -- Each set can have its own highlight colour, picked from the swatches
    -- beside the equipment manager (further down). Kept by set name.
    ns.db.setColors = type(ns.db.setColors) == "table" and ns.db.setColors or {}
    local function ColorOf(name)
        return ns.db.setColors[name] or SET_COLOR
    end

    -- item id -> names of the sets it is in, and the colour of the first of them
    local inSet, inSetColor = {}, {}
    local setNames = {}
    local function Rebuild()
        wipe(inSet)
        wipe(inSetColor)
        wipe(setNames)
        local ids = C_EquipmentSet.GetEquipmentSetIDs() or {}
        table.sort(ids)
        for _, setID in ipairs(ids) do
            local name = C_EquipmentSet.GetEquipmentSetInfo(setID) or "?"
            setNames[#setNames + 1] = name
            for _, itemID in pairs(C_EquipmentSet.GetItemIDs(setID) or {}) do
                if type(itemID) == "number" and itemID > 1 then
                    inSet[itemID] = inSet[itemID] and (inSet[itemID] .. ", " .. name) or name
                    inSetColor[itemID] = inSetColor[itemID] or ColorOf(name)
                end
            end
        end
    end

    local marks = setmetatable({}, { __mode = "k" }) -- item button -> our textures

    local function Mark(button, id)
        if id == nil then id = button.info and button.info.itemID end -- Bagnon's buttons carry it
        local sets = id and inSet[id]
        local mark = marks[button]
        if not sets then
            if mark then mark:Hide() end
            return
        end
        if not mark then
            mark = CreateFrame("Frame", nil, button)
            mark:SetAllPoints()
            mark:SetFrameLevel(button:GetFrameLevel() + 2)
            mark.parts = {}
            local function side(p1, p2, vertical)
                local t = mark:CreateTexture(nil, "OVERLAY")
                mark.parts[#mark.parts + 1] = t
                t:SetColorTexture(SET_COLOR[1], SET_COLOR[2], SET_COLOR[3], 1)
                t:SetPoint(p1)
                t:SetPoint(p2)
                if vertical then t:SetWidth(2) else t:SetHeight(2) end
            end
            side("TOPLEFT", "TOPRIGHT")
            side("BOTTOMLEFT", "BOTTOMRIGHT")
            side("TOPLEFT", "BOTTOMLEFT", true)
            side("TOPRIGHT", "BOTTOMRIGHT", true)
            -- corner tab, top-left
            local tab = mark:CreateTexture(nil, "OVERLAY", nil, 1)
            tab:SetColorTexture(SET_COLOR[1], SET_COLOR[2], SET_COLOR[3], 1)
            tab:SetSize(9, 9)
            tab:SetPoint("TOPLEFT")
            mark.parts[#mark.parts + 1] = tab
            marks[button] = mark
        end
        -- in its set's colour
        local c = inSetColor[id] or SET_COLOR
        for _, part in ipairs(mark.parts) do part:SetColorTexture(c[1], c[2], c[3], 1) end
        mark:Show()
    end
    local SafeMark = ns.Safe("set gear highlight", Mark)
    ns.MarkSetItem = SafeMark -- the bank uses the same marks

    -- Bagnon, if present
    local bagnon = _G.Bagnon or _G.BagBrother
    local Item = bagnon and bagnon.Item
    if Item and Item.UpdateBorder then
        hooksecurefunc(Item, "UpdateBorder", function(button) SafeMark(button) end)
    end

    -- The game's own bags: each bag window repaints its buttons through
    -- UpdateItems, so the marks are refreshed right after that.
    local stock = {} -- every stock item button we have seen
    local function MarkBag(frame)
        if not (frame and frame.EnumerateValidItems) then return end
        for _, button in frame:EnumerateValidItems() do
            local bag = button.GetBagID and button:GetBagID()
            local slot = button.GetID and button:GetID()
            local id = bag and slot and C_Container and C_Container.GetContainerItemID
                and ns.Clean(C_Container.GetContainerItemID(bag, slot))
            stock[button] = true
            Mark(button, id or false)
        end
    end
    local SafeMarkBag = ns.Safe("set gear highlight (bags)", MarkBag)
    local bagFrames = { ContainerFrameCombinedBags }
    for i = 1, 13 do bagFrames[#bagFrames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in pairs(bagFrames) do
        if frame and frame.UpdateItems then
            hooksecurefunc(frame, "UpdateItems", SafeMarkBag)
        end
    end
    local function MarkAllStock()
        for _, frame in pairs(bagFrames) do
            if frame and frame.IsShown and frame:IsShown() then SafeMarkBag(frame) end
        end
    end

    -- which sets an item is in, at the bottom of its tooltip
    if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local id = data and ns.Clean(data.id)
            local sets = id and inSet[id]
            if sets and tooltip and tooltip.AddLine then
                local c = inSetColor[id] or SET_COLOR
                tooltip:AddLine("Equipment set: " .. sets, c[1], c[2], c[3])
            end
        end)
    end

    local RefreshPanel -- set below, once the swatch panel exists
    local Refresh = ns.Safe("set gear list", function()
        Rebuild()
        for button in pairs(marks) do
            if not stock[button] then SafeMark(button) end
        end
        MarkAllStock()
        if RefreshPanel then RefreshPanel() end
    end)

    -----------------------------------------------------------------------
    -- Colour swatches beside the equipment manager: one per saved set.
    -- Click a swatch to pick that set's bag highlight colour; right-click
    -- puts it back to the default teal.
    -----------------------------------------------------------------------
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

    local function BuildPanel()
        -- whichever equipment manager this client has; the panel is its child,
        -- so it shows and hides with it
        local host = (PaperDollFrame and PaperDollFrame.EquipmentManagerPane)
            or _G.PaperDollEquipmentManagerPane or _G.GearManagerDialog or _G.GearManagerFrame
            or _G.PaperDollFrame
        if not (host and CharacterFrame) then return end
        ns.db.setPanelHost = host.GetName and host:GetName() or "unnamed" -- for troubleshooting

        local panel = CreateFrame("Frame", nil, host)
        panel:SetFrameStrata("HIGH")
        -- clear of the column of tabs that hangs off the character window's right edge
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 58, -24)
        ns.Edge(panel)
        local back = panel:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0.08, 0.09, 0.08, 0.95)
        local title = ns.Text(panel, 13, "LEFT")
        title:SetPoint("TOPLEFT", 8, -7)
        title:SetText("Bag highlight")
        title:SetTextColor(0.6, 0.63, 0.6)
        local empty = ns.Text(panel, 12, "LEFT")
        empty:SetPoint("TOPLEFT", 8, -28)
        empty:SetText("No saved sets yet")
        empty:SetTextColor(0.5, 0.5, 0.5)

        local rows = {}
        RefreshPanel = function()
            local widest = title:GetStringWidth() or 80
            for n, name in ipairs(setNames) do
                local row = rows[n]
                if not row then
                    row = CreateFrame("Button", nil, panel)
                    row:SetHeight(20)
                    row:SetPoint("TOPLEFT", 8, -26 - (n - 1) * 22)
                    row:SetPoint("RIGHT", -8, 0)
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    local rim = row:CreateTexture(nil, "BACKGROUND")
                    rim:SetColorTexture(0, 0, 0, 1)
                    rim:SetSize(18, 18)
                    rim:SetPoint("LEFT")
                    row.swatch = row:CreateTexture(nil, "ARTWORK")
                    row.swatch:SetPoint("TOPLEFT", rim, 1, -1)
                    row.swatch:SetPoint("BOTTOMRIGHT", rim, -1, 1)
                    row.label = ns.Text(row, 13, "LEFT")
                    row.label:SetPoint("LEFT", rim, "RIGHT", 7, 0)
                    row:SetScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            ns.db.setColors[self.set] = nil
                            Refresh()
                            return
                        end
                        local now = ColorOf(self.set)
                        local color = { now[1], now[2], now[3] }
                        ns.db.setColors[self.set] = color
                        PickColor(color, Refresh)
                    end)
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(self.set or "")
                        GameTooltip:AddLine("Click to choose the colour this set's gear is framed with in your bags.", 1, 1, 1, true)
                        GameTooltip:AddLine("Right-click to reset.", 0.6, 0.6, 0.6)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    rows[n] = row
                end
                local c = ColorOf(name)
                row.set = name
                row.swatch:SetColorTexture(c[1], c[2], c[3], 1)
                row.label:SetText(name)
                widest = math.max(widest, 25 + (row.label:GetStringWidth() or 60))
                row:Show()
            end
            for n = #setNames + 1, #rows do rows[n]:Hide() end
            empty:SetShown(#setNames == 0)
            widest = math.max(widest, #setNames == 0 and (empty:GetStringWidth() or 100) or 0)
            panel:SetSize(widest + 16, 30 + math.max(#setNames, 1) * 22)
        end
        panel:SetScript("OnShow", Refresh)
    end
    pcall(BuildPanel)

    local events = CreateFrame("Frame")
    events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", Refresh)
    Refresh()
end

local function InitChrome()
    InitSetGlow()
    InitXP()
    InitMicro()
    InitBags()
    if not ns.db.tracker then InitTracker() end -- the scrollable quest list replaces the tracker otherwise
end

ns.modules[#ns.modules + 1] = { setting = "chrome", init = InitChrome }
ns.modules[#ns.modules + 1] = { setting = "font", init = InitFont }
