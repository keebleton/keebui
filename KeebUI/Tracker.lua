-- KeebUI quest list: a plain, scrollable replacement for the built-in quest
-- tracker. No header bar, no background; about half the height the built-in
-- one takes. Mouse wheel scrolls. Click a quest to open it, shift-click to
-- stop tracking it.

local ADDON, ns = ...

local WIDTH, HEIGHT = 270, 290
local TITLE_SIZE, LINE_SIZE = 14, 13
local INDENT, ROW_GAP, QUEST_GAP = 10, 2, 8
local WHEEL_STEP = 40

local function Init()
    local Q = C_QuestLog
    if not (Q and Q.GetInfo and Q.GetLogIndexForQuestID) then return end

    local anchor = ns.Anchor("tracker", "Quests", WIDTH, HEIGHT, 608, 577)
    local scroll = CreateFrame("ScrollFrame", "KeebUIQuests", anchor)
    scroll:SetAllPoints()
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH, 1)
    scroll:SetScrollChild(child)

    -- thin marker on the right edge: only there when there is more to scroll to
    local thumb = anchor:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.35)
    thumb:SetWidth(2)
    thumb:Hide()

    local contentHeight = 0

    local function Scroll(to)
        local limit = math.max(0, contentHeight - HEIGHT)
        to = math.max(0, math.min(limit, to))
        scroll:SetVerticalScroll(to)
        if limit > 0 then
            local size = math.max(16, HEIGHT * HEIGHT / contentHeight)
            thumb:SetHeight(size)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 4, -(HEIGHT - size) * (to / limit))
            thumb:Show()
        else
            thumb:Hide()
        end
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        Scroll(self:GetVerticalScroll() - delta * WHEEL_STEP)
    end)

    -- pools: text lines and one invisible click target per quest
    local lines, buttons = {}, {}
    local usedLines, usedButtons, y = 0, 0, 0

    local function Line(text, size, r, g, b, indent)
        usedLines = usedLines + 1
        local fs = lines[usedLines]
        if not fs then
            fs = ns.Text(child, size, "LEFT")
            fs:SetWordWrap(true)
            fs:SetJustifyV("TOP")
            lines[usedLines] = fs
        end
        ns.SetFont(fs, size)
        fs:SetWidth(WIDTH - indent)
        fs:SetText(text)
        fs:SetTextColor(r, g, b)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", indent, -y)
        fs:Show()
        local height = fs:GetStringHeight() or size
        y = y + height + ROW_GAP
        return fs, height
    end

    local function OnClick(self)
        local id = self.questID
        if not id then return end
        if IsShiftKeyDown() then
            if Q.RemoveQuestWatch then pcall(Q.RemoveQuestWatch, id) end
        elseif not InCombatLockdown() and QuestMapFrame_OpenToQuestDetails then
            pcall(QuestMapFrame_OpenToQuestDetails, id)
        end
    end

    local function Target(title, top, height, questID)
        usedButtons = usedButtons + 1
        local b = buttons[usedButtons]
        if not b then
            b = CreateFrame("Button", nil, child)
            b:SetScript("OnClick", OnClick)
            b:SetScript("OnEnter", function(self) if self.title then self.title:SetAlpha(0.7) end end)
            b:SetScript("OnLeave", function(self) if self.title then self.title:SetAlpha(1) end end)
            buttons[usedButtons] = b
        end
        b.questID, b.title = questID, title
        title:SetAlpha(1)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -top)
        b:SetSize(WIDTH, height)
        b:Show()
    end

    -- The quests to list: the ones being tracked, or the whole log if none are.
    local function Collect()
        local ids = {}
        local watched = Q.GetNumQuestWatches and Q.GetNumQuestWatches() or 0
        for i = 1, watched do
            local id = Q.GetQuestIDForQuestWatchIndex and Q.GetQuestIDForQuestWatchIndex(i)
            if id then ids[#ids + 1] = id end
        end
        if #ids == 0 and Q.GetNumQuestLogEntries then
            for i = 1, Q.GetNumQuestLogEntries() do
                local info = Q.GetInfo(i)
                if info and not info.isHeader and not info.isHidden and info.questID then
                    ids[#ids + 1] = info.questID
                end
            end
        end
        return ids
    end

    local function Refresh()
        usedLines, usedButtons, y = 0, 0, 0
        for _, id in ipairs(Collect()) do
            local index = Q.GetLogIndexForQuestID(id)
            local info = index and Q.GetInfo(index)
            if info and info.title then
                local done = (Q.IsComplete and Q.IsComplete(id)) or (Q.ReadyForTurnIn and Q.ReadyForTurnIn(id))
                local level = info.level or info.difficultyLevel
                local r, g, b = 1, 0.82, 0
                if done then
                    r, g, b = 0.35, 0.9, 0.45
                elseif level and level > 0 and GetQuestDifficultyColor then
                    local c = GetQuestDifficultyColor(level)
                    if c then r, g, b = c.r, c.g, c.b end
                end
                local text = (level and level > 0) and ("[%d] %s"):format(level, info.title) or info.title
                local top = y
                local title, height = Line(text, TITLE_SIZE, r, g, b, 0)
                Target(title, top, height, id)

                if done then
                    Line("Ready for turn-in", LINE_SIZE, 0.6, 0.85, 0.65, INDENT)
                else
                    local objectives = Q.GetQuestObjectives and Q.GetQuestObjectives(id) or {}
                    for _, objective in ipairs(objectives) do
                        if objective.text and objective.text ~= "" then
                            if objective.finished then
                                Line(objective.text, LINE_SIZE, 0.5, 0.5, 0.5, INDENT)
                            else
                                Line(objective.text, LINE_SIZE, 0.92, 0.92, 0.92, INDENT)
                            end
                        end
                    end
                end
                y = y + QUEST_GAP
            end
        end
        for i = usedLines + 1, #lines do lines[i]:Hide() end
        for i = usedButtons + 1, #buttons do buttons[i]:Hide() end
        contentHeight = y
        child:SetHeight(math.max(1, y))
        Scroll(scroll:GetVerticalScroll())
    end
    local SafeRefresh = ns.Safe("quest list", Refresh)

    -- quest events come in bursts; redraw once per burst
    local pending = false
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(0.15, function()
            pending = false
            SafeRefresh()
        end)
    end)
    SafeRefresh()

    -- The built-in tracker steps aside. The game puts it back whenever it
    -- re-lays out the right side of the screen, so this is re-checked: it is
    -- kept invisible always, and shrunk and tucked away whenever out of combat.
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    local function HideBuiltIn()
        local stock = ObjectiveTrackerFrame
        if not stock then return end
        stock:SetAlpha(0)
        if InCombatLockdown() then return end
        if stock:GetParent() ~= hidden then stock:SetParent(hidden) end
        if stock:GetScale() > 0.01 then stock:SetScale(0.001) end
    end
    local SafeHide = ns.Safe("hide built-in tracker", HideBuiltIn)
    SafeHide()
    C_Timer.NewTicker(0.5, SafeHide)
end

ns.modules[#ns.modules + 1] = { setting = "tracker", init = Init }
