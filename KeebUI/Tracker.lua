-- KeebUI quest list: a plain, scrollable replacement for the built-in quest
-- tracker. No header bar, no background; about half the height the built-in
-- one takes. Mouse wheel scrolls.
--   click          open the quest
--   shift-click    put a link to it in chat
--   ctrl-click     stop tracking it
--   right-click    menu: open, track / stop tracking, share, link, abandon

local ADDON, ns = ...

local WIDTH, HEIGHT = 270, 290
local TITLE_SIZE, LINE_SIZE = 14, 13
local INDENT, ROW_GAP, QUEST_GAP = 10, 2, 8
local WHEEL_STEP = 40

---------------------------------------------------------------------------
-- Questie. It has a quest tracker of its own, and with both on there were two
-- lists, and Questie moved the tracking into its own list, which left this one
-- showing the whole quest log. So the two take turns, decided by Questie's own
-- "tracker enabled" setting:
--   * Questie's tracker on  -> this list stays off and leaves the screen to it
--   * Questie's tracker off -> this list runs, and Questie's map icons follow
--     what is tracked here; right-click also offers Questie's "show on map"
--     and waypoint, and the list redraws when Questie reports progress
-- "/keebui questie" (or the button under Extras) switches between the two.
---------------------------------------------------------------------------
local function QuestieModule(name)
    if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
    local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    return ok and module or nil
end

function ns.QuestieLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie") and Questie ~= nil
end

-- Is Questie's own tracker switched on? (nil when Questie is not there)
function ns.QuestieTrackerOn()
    if not ns.QuestieLoaded() then return nil end
    local ok, on = pcall(function() return Questie.db.profile.trackerEnabled end)
    if not ok then return nil end
    return on ~= false
end

-- Switch which list is used. Both ways reload the interface (Questie's own
-- switch does that itself).
function ns.UseQuestieTracker(useQuestie)
    if InCombatLockdown() then
        ns.Print("can't switch quest lists in combat.")
        return
    end
    local tracker = QuestieModule("QuestieTracker")
    if not tracker then
        ns.Print("Questie isn't running.")
        return
    end
    if useQuestie then
        ns.db.tracker = true -- stays on, steps aside while Questie's is on
        tracker:Enable()
    else
        ns.db.tracker = true
        tracker:Disable()
    end
end

local function Init()
    local Q = C_QuestLog
    if not (Q and Q.GetInfo and Q.GetLogIndexForQuestID) then return end

    if ns.QuestieTrackerOn() then
        -- Questie's tracker is in charge; say so once per character
        local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
        ns.db.questieNoted = type(ns.db.questieNoted) == "table" and ns.db.questieNoted or {}
        if not ns.db.questieNoted[who] then
            ns.db.questieNoted[who] = true
            ns.Print("Questie's quest tracker is on, so KeebUI's quest list is staying out of its way. " ..
                "To use KeebUI's list instead, type /keebui questie.")
        end
        return
    end

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

    -----------------------------------------------------------------------
    -- What can be done to a quest. Each uses the game's own way of doing it
    -- where it has one, so sharing and abandoning behave exactly as they do
    -- from the quest log (abandoning still asks "are you sure?").
    -----------------------------------------------------------------------
    local function Open(id)
        if InCombatLockdown() then return end
        if QuestMapFrame_OpenToQuestDetails then pcall(QuestMapFrame_OpenToQuestDetails, id) end
    end

    local function IsTracked(id)
        if Q.GetQuestWatchType then
            local ok, kind = pcall(Q.GetQuestWatchType, id)
            if ok then return kind ~= nil end
        end
        if Q.IsQuestWatched then
            local ok, on = pcall(Q.IsQuestWatched, id)
            if ok then return on and true or false end
        end
        return false
    end

    local function Untrack(id)
        if Q.RemoveQuestWatch then pcall(Q.RemoveQuestWatch, id) end
    end

    local function Track(id)
        if Q.AddQuestWatch then pcall(Q.AddQuestWatch, id) end
    end

    local function Link(id)
        local link = GetQuestLink and GetQuestLink(id)
        if not link then return end
        -- into the chat line being typed, or a new one if none is open
        local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
        local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
        local ok, added = false, false
        if insert then ok, added = pcall(insert, link) end
        if not (ok and added) and open then pcall(open, link) end
    end

    local function CanShare(id)
        if not IsInGroup() then return false end
        if Q.IsPushableQuest then
            local ok, can = pcall(Q.IsPushableQuest, id)
            if ok then return can and true or false end
        end
        return true
    end

    local function Share(id)
        if QuestMapQuestOptions_ShareQuest then
            pcall(QuestMapQuestOptions_ShareQuest, id)
        elseif Q.SetSelectedQuest and QuestLogPushQuest then
            Q.SetSelectedQuest(id)
            pcall(QuestLogPushQuest)
        end
    end

    local function Abandon(id)
        if QuestMapQuestOptions_AbandonQuest then
            pcall(QuestMapQuestOptions_AbandonQuest, id)
        elseif Q.SetSelectedQuest and Q.SetAbandonQuest then
            Q.SetSelectedQuest(id)
            Q.SetAbandonQuest()
            local index = Q.GetLogIndexForQuestID(id)
            local info = index and Q.GetInfo(index)
            StaticPopup_Show("ABANDON_QUEST", info and info.title or "")
        end
    end

    local function Menu(owner, id)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local index = Q.GetLogIndexForQuestID(id)
        local info = index and Q.GetInfo(index)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(info and info.title or "Quest")
            root:CreateButton("Open", function() Open(id) end)
            if IsTracked(id) then
                root:CreateButton("Stop tracking", function() Untrack(id) end)
            else
                root:CreateButton("Track", function() Track(id) end)
            end
            local share = root:CreateButton("Share with group", function() Share(id) end)
            if not CanShare(id) then share:SetEnabled(false) end
            root:CreateButton("Link in chat", function() Link(id) end)
            local utils = ns.QuestieLoaded() and QuestieModule("TrackerUtils")
            if utils and utils.ShowQuestOnMap then
                root:CreateButton("Show on map (Questie)", function()
                    local ok, shown = pcall(utils.ShowQuestOnMap, id)
                    if not (ok and shown) then ns.Print("Questie has no location for that quest.") end
                end)
                if utils.IsTomTomAvailable and utils.SetQuestTomTomTarget then
                    local okTom, hasTom = pcall(utils.IsTomTomAvailable)
                    if okTom and hasTom then
                        root:CreateButton("Set waypoint (Questie)", function()
                            local ok, set = pcall(utils.SetQuestTomTomTarget, id)
                            if not (ok and set) then ns.Print("Questie has no location for that quest.") end
                        end)
                    end
                end
            end
            root:CreateDivider()
            root:CreateButton("|cffff6666Abandon|r", function() Abandon(id) end)
        end)
    end

    local function OnClick(self, mouse)
        local id = self.questID
        if not id then return end
        if mouse == "RightButton" then
            Menu(self, id)
        elseif IsShiftKeyDown() then
            Link(id)
        elseif IsControlKeyDown() then
            Untrack(id)
        else
            Open(id)
        end
    end

    local function Target(title, top, height, questID)
        usedButtons = usedButtons + 1
        local b = buttons[usedButtons]
        if not b then
            b = CreateFrame("Button", nil, child)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", ns.Safe("quest list click", OnClick))
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
    local function Soon()
        if pending then return end
        pending = true
        C_Timer.After(0.15, function()
            pending = false
            SafeRefresh()
        end)
    end
    events:SetScript("OnEvent", Soon)
    if ns.QuestieLoaded() and Questie.API and Questie.API.RegisterForQuestUpdates then
        pcall(Questie.API.RegisterForQuestUpdates, function() Soon() end)
    end
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
