-- KeebUI bar layout: bars 1-3 stacked bottom centre, menu and bags bottom right.
-- This is done by adding an Edit Mode layout called "KeebUI" (a copy of the
-- layout you were on, with only those pieces moved), so the game itself owns
-- the positions: nothing fights Edit Mode, and your old layout is still in
-- the Edit Mode layout list if you want it back.

local ADDON, ns = ...

local NAME = "KeebUI"
local OLD_NAME = "CleanUI" -- what this addon and its layout were called before the rename
local VERSION = 14
local BUTTON, PADDING = 45, 3      -- stock button size at 100% and the gap between buttons
-- The three stacked bars run at 90%: a button then covers about 61 screen
-- pixels, almost exactly the 59 pixels of icon art shown, so icons are drawn
-- at very nearly their true size instead of being stretched.
local STACK_SCALE = 0.9
local ROW = BUTTON * STACK_SCALE + PADDING -- distance from one row to the next
ns.STACK_WIDTH = 12 * BUTTON * STACK_SCALE + 11 * PADDING
local FIRST_ROW = 18               -- leaves room for the experience bar underneath
local EDGE = 4
local FRAME_TOP = 237               -- top edge of the player frame at its default spot
local RIGHT_SCALE = 0.9             -- the two right-hand bars run a little smaller
local RIGHT_BARS_TOP = 278          -- just below the minimap and its coordinates

local function FindSystem(layout, system, index)
    for _, entry in ipairs(layout.systems or {}) do
        if entry.system == system and entry.systemIndex == index then return entry end
    end
end

local function Anchor(entry, point, x, y, relativePoint)
    local a = entry.anchorInfo
    if type(a) ~= "table" then
        a = {}
        entry.anchorInfo = a
    end
    a.point, a.relativeTo, a.relativePoint, a.offsetX, a.offsetY = point, "UIParent", relativePoint or point, x, y
    entry.isInDefaultPosition = false
end

local function Set(entry, setting, value)
    if setting == nil or value == nil then return end
    entry.settings = entry.settings or {}
    for _, row in ipairs(entry.settings) do
        if row.setting == setting then
            row.value = value
            return
        end
    end
    entry.settings[#entry.settings + 1] = { setting = setting, value = value }
end

local function Arrange(layout)
    local system = Enum.EditModeSystem
    local index = Enum.EditModeActionBarSystemIndices or {}
    local setting = Enum.EditModeActionBarSetting or {}
    local horizontal = Enum.ActionBarOrientation and Enum.ActionBarOrientation.Horizontal

    for row, barIndex in ipairs({ index.MainBar, index.Bar2, index.Bar3 }) do
        local bar = barIndex ~= nil and FindSystem(layout, system.ActionBar, barIndex)
        if bar then
            Anchor(bar, "BOTTOM", 0, FIRST_ROW + (row - 1) * ROW)
            Set(bar, setting.Orientation, horizontal)
            Set(bar, setting.NumRows, 1)
            Set(bar, setting.NumIcons, 12)
            Set(bar, setting.IconSize, 4) -- 90% (the setting counts in 10% steps from 50%)
            Set(bar, setting.IconPadding, PADDING)
            if barIndex == index.MainBar then
                Set(bar, setting.HideBarArt, 1)
                Set(bar, setting.HideBarScrolling, 1) -- the page number with its up/down arrows
            end
        end
    end

    -- the two right-hand bars: tucked up under the minimap so their bottom
    -- ends well above the bags, leaving that corner free for the tooltip
    for column, barIndex in ipairs({ index.RightBar1, index.RightBar2 }) do
        local bar = barIndex ~= nil and FindSystem(layout, system.ActionBar, barIndex)
        if bar then
            Anchor(bar, "TOPRIGHT", -EDGE - (column - 1) * (BUTTON * RIGHT_SCALE + PADDING), -RIGHT_BARS_TOP)
            Set(bar, setting.IconSize, 4) -- 90%
            Set(bar, setting.IconPadding, PADDING)
        end
    end

    -- stance buttons (paladin auras): two columns to the right of the bar stack.
    -- Pet buttons use the same spot.
    local half = ns.STACK_WIDTH / 2
    local stance = index.StanceBar ~= nil and FindSystem(layout, system.ActionBar, index.StanceBar)
    if stance then
        Anchor(stance, "BOTTOMLEFT", half + 10, FIRST_ROW, "BOTTOM")
        Set(stance, setting.Orientation, Enum.ActionBarOrientation and Enum.ActionBarOrientation.Vertical)
        Set(stance, setting.NumRows, 2) -- on a vertical bar this is the number of columns
    end
    local pet = index.PetActionBar ~= nil and FindSystem(layout, system.ActionBar, index.PetActionBar)
    if pet then
        -- Right of the bar stack (the stance buttons' spot; no class has both),
        -- as a tidy block of two rows of five that lines up with the bottom of
        -- the stack. Top row: attack, follow, stay and the first two abilities;
        -- bottom row: the other abilities and the three stances. Empty slots
        -- are drawn too, so the block keeps its shape whatever the pet knows.
        Anchor(pet, "BOTTOMLEFT", half + 10, FIRST_ROW, "BOTTOM")
        Set(pet, setting.Orientation, Enum.ActionBarOrientation and Enum.ActionBarOrientation.Horizontal)
        Set(pet, setting.NumRows, 2)
        Set(pet, setting.IconSize, 5) -- 100%
        Set(pet, setting.IconPadding, 2)
        Set(pet, setting.AlwaysShowButtons, 1)
    end

    -- the "Request Stop" / leave-vehicle button: left of the top row of the
    -- stack instead of on top of the bars
    local leave = system.VehicleLeaveButton and FindSystem(layout, system.VehicleLeaveButton, nil)
    if leave then Anchor(leave, "BOTTOMRIGHT", -half - 10, FIRST_ROW + 2 * ROW, "BOTTOM") end

    -- cooldown manager, resting on top of the player frame: tracked buffs on
    -- its right end, tracked cooldowns on its left end
    local viewer = Enum.EditModeCooldownViewerSystemIndices
    if system.CooldownViewer and viewer then
        local essential = viewer.Essential ~= nil and FindSystem(layout, system.CooldownViewer, viewer.Essential)
        if essential then Anchor(essential, "BOTTOMLEFT", -370, FRAME_TOP + 6, "BOTTOM") end
        local buffs = viewer.BuffIcon ~= nil and FindSystem(layout, system.CooldownViewer, viewer.BuffIcon)
        if buffs then Anchor(buffs, "BOTTOMRIGHT", -130, FRAME_TOP + 6, "BOTTOM") end
    end

    -- quest tracker: the shortest height the game allows (about half of the default)
    local tracker = system.ObjectiveTracker and FindSystem(layout, system.ObjectiveTracker, nil)
    local trackerHeight = Enum.EditModeObjectiveTrackerSetting and Enum.EditModeObjectiveTrackerSetting.Height
    if tracker then Set(tracker, trackerHeight, 0) end

    -- the default tooltip spot: above the bags with room for its health bar
    local tooltip = system.HudTooltip and FindSystem(layout, system.HudTooltip, nil)
    if tooltip then Anchor(tooltip, "BOTTOMRIGHT", -EDGE, 112) end

    local micro = system.MicroMenu and FindSystem(layout, system.MicroMenu, nil)
    if micro then Anchor(micro, "BOTTOMRIGHT", -EDGE, EDGE) end
    local bags = system.Bags and FindSystem(layout, system.Bags, nil)
    if bags then Anchor(bags, "BOTTOMRIGHT", -EDGE, EDGE + 47) end -- a small clear gap above the menu row

    -- experience bar: bottom centre, about as wide as the bar stack
    local trackIndex = Enum.EditModeStatusTrackingBarSystemIndices
    local xp = system.StatusTrackingBar and trackIndex and trackIndex.StatusTrackingBar1 ~= nil
        and FindSystem(layout, system.StatusTrackingBar, trackIndex.StatusTrackingBar1)
    if xp then
        Anchor(xp, "BOTTOM", 0, 2)
        local size = Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
        Set(xp, size, 0) -- narrowest step
    end
end

-- Returns true when done, false to try again later, or nil plus a reason when it cannot be done.
local function Write(force)
    if InCombatLockdown() then return false end
    local manager = EditModeManagerFrame
    if not (manager and manager.accountSettings) then return false end
    if manager:IsShown() then return false end
    local presetManager = EditModePresetLayoutManager
    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout
        and presetManager and presetManager.GetCopyOfPresetLayouts
        and Enum.EditModeSystem and Enum.EditModeLayoutType) then
        return nil, "this client has no Edit Mode layouts"
    end

    local info = C_EditMode.GetLayouts()
    if not (info and type(info.layouts) == "table") then return false end
    local merged = presetManager:GetCopyOfPresetLayouts()
    if type(merged) ~= "table" or #merged == 0 then return false end
    local presetCount = #merged

    -- the layout this character is on now is the starting point
    local active = info.activeLayout or 1
    local base = active > presetCount and info.layouts[active - presetCount] or merged[active] or merged[1]

    -- remembered so "Restore my old UI" can switch back to it
    if base and base.layoutName and base.layoutName ~= NAME and base.layoutName ~= OLD_NAME then
        ns.db.prevLayoutName = base.layoutName
    end

    local slot, accountLayouts = nil, 0
    for _, layout in ipairs(info.layouts) do
        merged[#merged + 1] = layout
        if layout.layoutName == OLD_NAME then layout.layoutName = NAME end -- renamed in place, same slot
        if layout.layoutName == NAME then slot = #merged end
        if layout.layoutType == Enum.EditModeLayoutType.Account then accountLayouts = accountLayouts + 1 end
    end

    if slot then
        if not force then
            return true -- already made once; where you go from there is your choice
        end
        Arrange(merged[slot])
    else
        local limit = Constants and Constants.EditModeConstants and Constants.EditModeConstants.EditModeMaxLayoutsPerType
        if limit and accountLayouts >= limit then
            return nil, "you already have the maximum number of Edit Mode layouts; delete one and try again"
        end
        local layout = CopyTable(base)
        layout.layoutIndex = nil
        layout.layoutType = Enum.EditModeLayoutType.Account
        layout.layoutName = NAME
        Arrange(layout)
        -- account layouts are listed before character ones
        slot = #merged + 1
        for i = presetCount + 1, #merged do
            if merged[i].layoutType == Enum.EditModeLayoutType.Character then
                slot = i
                break
            end
        end
        table.insert(merged, slot, layout)
    end

    info.layouts = merged
    info.activeLayout = slot
    C_EditMode.SaveLayouts(info)
    C_EditMode.SetActiveLayout(slot)
    return true
end

local function Attempt(force, triesLeft)
    local ok, done, reason = pcall(Write, force)
    if not ok then
        ns.LogError("bar layout", done)
    elseif done then
        ns.db.layoutVersion = VERSION
        if force then ns.Print("bars stacked. Your previous layout is still in Edit Mode's layout list.") end
    elseif done == nil then
        ns.Print("couldn't arrange the bars: " .. (reason or "unknown reason") .. ".")
    elseif triesLeft > 0 then
        C_Timer.After(1, function() Attempt(force, triesLeft - 1) end)
    elseif force then
        ns.Print("couldn't arrange the bars right now (in combat or Edit Mode open). Try again in a moment.")
    end
end

-- Switch Edit Mode back to the layout that was active before KeebUI's.
-- (KeebUI's own layout stays in the list; delete it there if you like.)
function ns.RestoreLayout()
    local want = ns.db.prevLayoutName
    local presetManager = EditModePresetLayoutManager
    if not (want and C_EditMode and C_EditMode.GetLayouts and C_EditMode.SetActiveLayout
        and presetManager and presetManager.GetCopyOfPresetLayouts) then return end
    local info = C_EditMode.GetLayouts()
    local all = presetManager:GetCopyOfPresetLayouts() or {}
    for _, layout in ipairs(info and info.layouts or {}) do all[#all + 1] = layout end
    for index, layout in ipairs(all) do
        if layout.layoutName == want then
            C_EditMode.SetActiveLayout(index)
            return true
        end
    end
end

-- Used by the options window button.
function ns.StackBars()
    Attempt(true, 3)
end

-- Did the layout we wrote actually stick? On one account a write was
-- reported as done but the saved layout still held the old values at the
-- next login. So the first login after each write reads the layout back
-- and, if the second bar is not where this version puts it or the main bar
-- is not at this version's size, writes it again.
local function Stuck()
    if InCombatLockdown() then return nil end
    local manager = EditModeManagerFrame
    if not (manager and manager.accountSettings) then return nil end
    if not (C_EditMode and C_EditMode.GetLayouts and Enum.EditModeSystem) then return true end
    local info = C_EditMode.GetLayouts()
    if not (info and type(info.layouts) == "table") then return nil end
    local index = Enum.EditModeActionBarSystemIndices or {}
    local setting = Enum.EditModeActionBarSetting or {}
    for _, layout in ipairs(info.layouts) do
        if layout.layoutName == NAME then
            local main = index.MainBar ~= nil and FindSystem(layout, Enum.EditModeSystem.ActionBar, index.MainBar)
            local second = index.Bar2 ~= nil and FindSystem(layout, Enum.EditModeSystem.ActionBar, index.Bar2)
            if not (main and second and second.anchorInfo) then return true end -- nothing to compare
            local size
            for _, row in ipairs(main.settings or {}) do
                if row.setting == setting.IconSize then size = row.value end
            end
            local y = second.anchorInfo.offsetY or 0
            return size == 4 and math.abs(y - (FIRST_ROW + ROW)) < 0.6
        end
    end
    return false -- the layout is gone
end

local function Verify(triesLeft)
    local ok, stuck = pcall(Stuck)
    if not ok then
        ns.LogError("bar layout check", stuck)
    elseif stuck == nil then
        if triesLeft > 0 then C_Timer.After(1, function() Verify(triesLeft - 1) end) end
    elseif stuck then
        ns.db.layoutVerified = VERSION
    else
        ns.db.layoutRewrites = (ns.db.layoutRewrites or 0) + 1
        Attempt(true, 5) -- write it again; checked once more at the next login
    end
end

local function Init()
    if ns.db.layoutVersion ~= VERSION then
        Attempt(true, 15) -- a new version of the layout: write it
    elseif ns.db.layoutVerified ~= VERSION then
        Verify(15)
    end
end

ns.modules[#ns.modules + 1] = { setting = "bars", init = Init }
