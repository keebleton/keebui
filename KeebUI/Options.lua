-- KeebUI settings window. Five sections down the left, one page each, no
-- scrolling. One setting per row: a name, a line of description, and one
-- control. Only four kinds of control exist: a switch, a pick-one strip,
-- colour swatches, and a button.

local ADDON, ns = ...

local WIDTH, HEIGHT, SIDE, ROW = 580, 400, 140, 42
local GOLD = { 0.95, 0.76, 0.19 }

---------------------------------------------------------------------------
-- What goes on each page
---------------------------------------------------------------------------
-- kinds: "toggle" (key, reload?), "pick" (get/set, choices), "swatches" (colour table, entries),
--        "button" (label, click), "slider" (key)
local function Pages()
    local function threat() return ns.ThreatSettings and ns.ThreatSettings() end
    local other = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForeverThreatPlate")
    return {
        { name = "General", about = "Size, placement and text.", rows = {
            { kind = "slider", label = "Frame size", note = "Scales every KeebUI frame", key = "scale" },
            { kind = "button", label = "Move frames", note = "Drag the green boxes, then lock",
                text = function() return ns.IsUnlocked() and "Lock frames" or "Move frames" end,
                click = function() ns.SetUnlocked(not ns.IsUnlocked()) end },
            { kind = "button", label = "Reset positions", note = "Put every frame back where it started",
                text = "Reset", click = function()
                    if InCombatLockdown() then return end
                    wipe(ns.db.pos)
                    ns.PlaceAnchors()
                end },
            { kind = "cycle", label = "Font", note = "Pick from the list; scroll it for more", reload = true,
                get = function() return ns.db.fontFace or ns.Fonts()[1][2] end,
                set = function(v) ns.db.fontFace = v end,
                choices = function() return ns.Fonts() end },
            { kind = "toggle", label = "Use it for the game's own text too", note = "Tooltips, chat, quest text and the like",
                key = "font", reload = true },
            { kind = "toggle", label = "Flat tooltip", note = "Matches the rest of the UI", key = "skin", reload = true },
            { kind = "button", label = "Restore my old UI", note = "Puts back your settings and layout, turns KeebUI's pieces off",
                text = "Restore", click = function() ns.RestoreOldUI() end },
        } },
        { name = "Frames", about = "Player, target, party and raid.", rows = {
            { kind = "pick", label = "Unit frames", note = "Player, target, target of target, pet", reload = true,
                get = function() return ns.db.unitFrames and "keebui" or "blizzard" end,
                set = function(v) ns.db.unitFrames = (v == "keebui") end,
                choices = { { "keebui", "KeebUI" }, { "blizzard", "Blizzard" } } },
            { kind = "toggle", label = "Colour Blizzard health bars", note = "Class colour, when using Blizzard's frames",
                key = "blizzClassColor", reload = true },
            { kind = "toggle", label = "Party frames", note = "Column above your frame", key = "party", reload = true },
            { kind = "toggle", label = "Raid frames", note = "Grid of groups", key = "raid", reload = true },
            { kind = "button", label = "Raid and party frames", note = "Layout, auras and click casting",
                text = "Customise", click = function() if ns.ToggleFrameOptions then ns.ToggleFrameOptions() end end },
            { kind = "pick", label = "Raid cell size", note = "Auto picks by how many are in the raid",
                get = function() return ns.db.raidPreset or "auto" end,
                set = function(v)
                    ns.db.raidPreset = v
                    if ns.ApplyRaidPreset then ns.ApplyRaidPreset() end
                end,
                choices = { { "auto", "Auto" }, { "10", "10" }, { "20", "20" }, { "40", "40" } } },
            { kind = "toggle", label = "Cast bar and swing timer", key = "castSwing", reload = true },
            { kind = "toggle", label = "Five-second rule", note = "Marker on your mana bar after you spend mana", key = "fiveSecond", reload = true },
            { kind = "pick", label = "Combo points", note = "Rogue and cat form", reload = true,
                get = function() return ns.db.combo or "target" end,
                set = function(v) ns.db.combo = v end,
                choices = { { "target", "Target" }, { "player", "Player" }, { "bars", "Bars" }, { "off", "Off" } } },
        } },
        { name = "Action bars", about = "Buttons, layout and what sits around them.", rows = {
            { kind = "toggle", label = "Button style and bar layout", note = "Rounded buttons, bars stacked in the middle",
                key = "bars", reload = true },
            { kind = "button", label = "Stack the bars again", note = "Rewrites the KeebUI layout in Edit Mode",
                text = "Stack", click = function() if ns.StackBars then ns.StackBars() end end },
            { kind = "toggle", label = "Trinket buttons", note = "Two slots with a pop-up of bag trinkets", key = "trinkets", reload = true },
            { kind = "toggle", label = "XP bar and menu buttons", note = "Also the equipment-set highlight in bags",
                key = "chrome", reload = true },
        } },
        { name = "Nameplates", about = "The bars over enemies' heads.", rows = {
            { kind = "toggle", label = "Clean nameplates", note = "Flat bar, name and level inside", key = "plates", reload = true },
            { kind = "toggle", label = "Threat colours",
                note = other and "Off while ForeverThreatPlate is installed" or "Colour a mob's bar by who it is on",
                get = function() return ns.db.threatColors ~= false end,
                set = function(v)
                    ns.db.threatColors = v
                    if ns.RefreshThreatColors then ns.RefreshThreatColors() end
                end },
            { kind = "pick", label = "I am", note = "Auto goes by stance, form or Righteous Fury",
                get = function() local t = threat() return t and t.mode or "auto" end,
                set = function(v)
                    local t = threat()
                    if t then t.mode = v end
                    if ns.RefreshThreatColors then ns.RefreshThreatColors() end
                end,
                choices = { { "auto", "Auto" }, { "tank", "Tank" }, { "dps", "Damage" } } },
            { kind = "swatches", label = "When tanking", note = "On you / slipping / nearly yours / elsewhere",
                colors = function() local t = threat() return t and t.tank end,
                entries = { "secure", "slipping", "gaining", "loose" } },
            { kind = "swatches", label = "When not tanking", note = "On you / slipping / close to pulling / elsewhere",
                colors = function() local t = threat() return t and t.dps end,
                entries = { "aggro", "slipping", "high", "safe" } },
        } },
        { name = "Extras", about = "Smaller helpers and other addons.", rows = {
            { kind = "toggle", label = "Scrollable quest list", note = "Replaces the built-in tracker", key = "tracker", reload = true },
            { kind = "toggle", label = "Raid tools", note = "Ready check, pull timer and marks bar; mark ring keybind", key = "raidTools", reload = true },
            { kind = "toggle", label = "Arcanite transmute alert", note = "Tells you when the cooldown is up", key = "transmute", reload = true },
            { kind = "button", label = "Errors", note = "Print anything that went wrong this session",
                text = "Show", click = function() SlashCmdList.KEEBUI("errors") end },
        } },
    }
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local function Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
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
    b:SetScript("OnClick", function(self)
        set(not get())
        self:Paint()
    end)
    return b
end

local function TextButton(parent, width)
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
    return b
end

-- a strip of choices, exactly one lit
local function Pick(parent, row, changed)
    local holder = CreateFrame("Frame", nil, parent)
    local x, buttons = 0, {}
    for _, choice in ipairs(row.choices) do
        local b = TextButton(holder, 10)
        b.label:SetText(choice[2])
        b:SetWidth((b.label:GetStringWidth() or 30) + 18)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + 2
        b.value = choice[1]
        b:SetScript("OnClick", function()
            row.set(choice[1])
            holder:Paint()
            changed()
        end)
        buttons[#buttons + 1] = b
    end
    holder:SetSize(x - 2, 22)
    function holder:Paint()
        local now = row.get()
        for _, b in ipairs(buttons) do
            if b.value == now then
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
    end
    return holder
end

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

local function Swatches(parent, row)
    local holder = CreateFrame("Frame", nil, parent)
    local swatches = {}
    for i, key in ipairs(row.entries) do
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(30, 18)
        b:SetPoint("LEFT", (i - 1) * 34, 0)
        local edge = Flat(b, 0, 0, 0, 1, "BACKGROUND")
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        b.fill = Flat(b, 1, 1, 1, 1, "BORDER")
        b.fill:SetAllPoints()
        b:SetScript("OnClick", function()
            local colors = row.colors()
            if not (colors and colors[key]) then return end
            PickColor(colors[key], function()
                holder:Paint()
                if ns.RefreshThreatColors then ns.RefreshThreatColors() end
            end)
        end)
        b.key = key
        swatches[i] = b
    end
    holder:SetSize(#row.entries * 34 - 4, 18)
    function holder:Paint()
        local colors = row.colors()
        for _, b in ipairs(swatches) do
            local c = colors and colors[b.key]
            if c then b.fill:SetColorTexture(c[1], c[2], c[3], 1) end
        end
    end
    return holder
end

local function Slider(parent, row)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(150, 16)
    s:SetMinMaxValues(0.7, 1.5)
    s:SetValueStep(0.05)
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
    local painting = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / 0.05 + 0.5) * 0.05
        value:SetText(("%d%%"):format(v * 100 + 0.5))
        if painting or InCombatLockdown() or ns.db[row.key] == v then return end
        ns.db[row.key] = v
        ns.PlaceAnchors()
    end)
    function s:Paint()
        painting = true
        self:SetValue(ns.db[row.key] or 1)
        value:SetText(("%d%%"):format((ns.db[row.key] or 1) * 100 + 0.5))
        painting = false
    end
    return s
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local window

local function Create()
    local f = CreateFrame("Frame", "KeebUIOptions", UIParent)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "KeebUIOptions") -- Escape closes it
    ns.Edge(f)
    local back = Flat(f, 0.08, 0.09, 0.08, 0.97)
    back:SetAllPoints()

    -- sidebar
    local side = Flat(f, 0.05, 0.06, 0.05, 1, "BORDER")
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE)
    local brand = ns.Text(f, 18, "LEFT")
    brand:SetPoint("TOPLEFT", 14, -14)
    brand:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    brand:SetText("KeebUI")
    -- a plain close button to match, instead of the game's ornate red one
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

    -- which settings differ from what was loaded at login (those need a reload)
    local loaded, reloadKeys = {}, {}
    local footer = ns.Text(f, 12, "LEFT")
    footer:SetPoint("BOTTOMLEFT", SIDE + 18, 16)
    footer:SetTextColor(0.6, 0.63, 0.6)
    local reload = TextButton(f, 96)
    reload:SetPoint("BOTTOMRIGHT", -14, 12)
    reload.label:SetText("Reload UI")
    reload:SetScript("OnClick", ReloadUI)
    local function Pending()
        local n = 0
        for id, read in pairs(reloadKeys) do
            if read() ~= loaded[id] then n = n + 1 end
        end
        if n == 0 then
            footer:SetText("")
            reload:Hide()
        else
            footer:SetText(n == 1 and "1 change needs a reload" or (n .. " changes need a reload"))
            reload:Show()
        end
    end

    local pages, tabs, controls = Pages(), {}, {}
    -- the window is as tall as its longest page needs, so the reload prompt
    -- at the bottom never lands on top of the last row
    local most = 0
    for _, page in ipairs(pages) do most = math.max(most, #page.rows) end
    f:SetHeight(math.max(HEIGHT, 14 + 44 + most * ROW + 8 + 46))
    local shown

    local function Show(index)
        shown = index
        for i, page in ipairs(pages) do
            page.frame:SetShown(i == index)
            tabs[i].mark:SetShown(i == index)
            tabs[i].fill:SetShown(i == index)
            tabs[i].label:SetTextColor(i == index and 1 or 0.6, i == index and 1 or 0.63, i == index and 1 or 0.6)
        end
        for _, control in ipairs(controls) do
            if control.Paint then control:Paint() end
        end
        Pending()
    end

    for i, page in ipairs(pages) do
        -- sidebar entry
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(SIDE, 30)
        tab:SetPoint("TOPLEFT", 0, -46 - (i - 1) * 30)
        tab.fill = Flat(tab, 0.11, 0.13, 0.11, 1, "ARTWORK")
        tab.fill:SetAllPoints()
        tab.mark = Flat(tab, GOLD[1], GOLD[2], GOLD[3], 1, "OVERLAY")
        tab.mark:SetPoint("TOPLEFT")
        tab.mark:SetPoint("BOTTOMLEFT")
        tab.mark:SetWidth(2)
        tab.label = ns.Text(tab, 14, "LEFT")
        tab.label:SetPoint("LEFT", 14, 0)
        tab.label:SetText(page.name)
        tab:SetScript("OnClick", function() Show(i) end)
        tabs[i] = tab

        -- the page
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", SIDE + 18, -14)
        p:SetPoint("BOTTOMRIGHT", -18, 46)
        page.frame = p
        local head = ns.Text(p, 16, "LEFT")
        head:SetPoint("TOPLEFT")
        head:SetText(page.name)
        local about = ns.Text(p, 12, "LEFT")
        about:SetPoint("TOPLEFT", 0, -22)
        about:SetTextColor(0.55, 0.58, 0.55)
        about:SetText(page.about)

        for n, row in ipairs(page.rows) do
            local y = -44 - (n - 1) * ROW
            local line = Flat(p, 1, 1, 1, 0.06, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", 0, y)
            line:SetPoint("TOPRIGHT", 0, y)
            local label = ns.Text(p, 14, "LEFT")
            label:SetPoint("TOPLEFT", 0, y - (row.note and 6 or 13))
            label:SetText(row.label)
            if row.note then
                local note = ns.Text(p, 12, "LEFT")
                note:SetPoint("TOPLEFT", 0, y - 23)
                note:SetTextColor(0.55, 0.58, 0.55)
                note:SetText(row.note)
            end

            local control
            local get = row.get or (row.key and function() return ns.db[row.key] end)
            local set = row.set or (row.key and function(v) ns.db[row.key] = v end)
            if row.kind == "toggle" then
                control = Switch(p, get, function(v)
                    set(v and true or false)
                    Pending()
                end)
            elseif row.kind == "pick" then
                control = Pick(p, row, Pending)
            elseif row.kind == "cycle" then
                -- a drop-down: the button shows the current choice in its own
                -- font; clicking opens the list, each entry drawn in its font
                control = TextButton(p, 170)
                local list = CreateFrame("Frame", nil, f)
                list:SetFrameStrata("TOOLTIP")
                list:SetPoint("TOPRIGHT", control, "BOTTOMRIGHT", 0, -2)
                list:EnableMouse(true)
                list:EnableMouseWheel(true)
                list:Hide()
                ns.Edge(list)
                local listBack = Flat(list, 0.1, 0.11, 0.1, 1)
                listBack:SetAllPoints()
                local VISIBLE, LINE = 10, 22
                local lines, offset = {}, 0

                local function Fill()
                    local choices, now = row.choices(), tostring(row.get()):lower()
                    local count = math.min(VISIBLE, #choices)
                    offset = math.max(0, math.min(offset, #choices - count))
                    list:SetSize(190, count * LINE + 4)
                    for n = 1, count do
                        local line = lines[n]
                        if not line then
                            line = CreateFrame("Button", nil, list)
                            line:SetSize(186, LINE)
                            line:SetPoint("TOPLEFT", 2, -2 - (n - 1) * LINE)
                            local shine = line:CreateTexture(nil, "HIGHLIGHT")
                            shine:SetAllPoints()
                            shine:SetColorTexture(1, 1, 1, 0.1)
                            line.label = ns.Text(line, 13, "LEFT")
                            line.label:SetPoint("LEFT", 8, 0)
                            line.label:SetPoint("RIGHT", -8, 0)
                            line:SetScript("OnClick", function(self)
                                row.set(self.value)
                                list:Hide()
                                control:Paint()
                                Pending()
                            end)
                            lines[n] = line
                        end
                        local choice = choices[n + offset]
                        line.value = choice[2]
                        if not line.label:SetFont(choice[2], 13, "OUTLINE") then line.label:SetFont(ns.FONT, 13, "OUTLINE") end
                        line.label:SetText(choice[1])
                        local current = choice[2]:lower() == now
                        line.label:SetTextColor(current and GOLD[1] or 0.9, current and GOLD[2] or 0.9, current and GOLD[3] or 0.9)
                        line:Show()
                    end
                    for n = count + 1, #lines do lines[n]:Hide() end
                end
                list:SetScript("OnMouseWheel", function(_, delta)
                    offset = offset - delta
                    Fill()
                end)
                -- closes when the mouse has been away from both the list and its button
                list:SetScript("OnUpdate", function(self, elapsed)
                    if self:IsMouseOver() or control:IsMouseOver() then
                        self.away = 0
                    else
                        self.away = (self.away or 0) + elapsed
                        if self.away > 0.6 then self:Hide() end
                    end
                end)
                p:HookScript("OnHide", function() list:Hide() end)

                function control:Paint()
                    local now = row.get()
                    local name = "?"
                    for _, choice in ipairs(row.choices()) do
                        if choice[2]:lower() == tostring(now):lower() then name = choice[1] end
                    end
                    if not self.label:SetFont(now, 13, "OUTLINE") then self.label:SetFont(ns.FONT, 13, "OUTLINE") end
                    self.label:SetText(name .. "  v")
                end
                control:SetScript("OnClick", function()
                    if list:IsShown() then
                        list:Hide()
                    else
                        -- open with the current choice in view
                        local choices, now = row.choices(), tostring(row.get()):lower()
                        offset = 0
                        for n, choice in ipairs(choices) do
                            if choice[2]:lower() == now then offset = n - 3 end
                        end
                        list.away = 0
                        Fill()
                        list:Show()
                    end
                end)
            elseif row.kind == "swatches" then
                control = Swatches(p, row)
            elseif row.kind == "slider" then
                control = Slider(p, row)
            elseif row.kind == "button" then
                control = TextButton(p, 96)
                local text = row.text
                function control:Paint()
                    self.label:SetText(type(text) == "function" and text() or text)
                end
                control:SetScript("OnClick", function(self)
                    row.click()
                    self:Paint()
                end)
            end
            if control then
                control:SetPoint("RIGHT", p, "TOPRIGHT", 0, y - ROW / 2)
                controls[#controls + 1] = control
            end
            if row.reload and get then
                local id = page.name .. ":" .. row.label
                loaded[id] = get()
                reloadKeys[id] = get
            end
        end
    end

    f:SetScript("OnShow", function() Show(shown or 1) end)
    f:SetScript("OnHide", function() ns.SetUnlocked(false) end)
    return f
end

function ns.ToggleOptions()
    window = window or Create()
    window:SetShown(not window:IsShown())
end

---------------------------------------------------------------------------
-- /keebui
---------------------------------------------------------------------------
SLASH_KEEBUI1 = "/keebui"
SLASH_KEEBUI2 = "/kui"
SLASH_KEEBUI3 = "/cleanui" -- the old name still works
SlashCmdList.KEEBUI = function(msg)
    SlashCmdList.KEEBUI_RAW = msg or "" -- file paths must keep their capitals
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "errors" then
        local any = false
        for text in pairs(ns.db.errors or {}) do
            any = true
            print("|cffff6666KeebUI:|r " .. text)
        end
        -- the game's own error reports seen this session (first line of each)
        for _, text in ipairs(ns.db.gameErrors or {}) do
            any = true
            print("|cffffaa55Game error:|r " .. (text:match("^[^\n]*") or text))
        end
        if not any then ns.Print("no errors this session.") end
    elseif msg:match("^combo") then
        local place = msg:match("^combo%s+(%a+)")
        if place == "target" or place == "player" or place == "bars" or place == "off" then
            ns.db.combo = place
            ns.Print("combo points: " .. place .. ". Type /reload to apply.")
        else
            ns.Print("combo points are set to \"" .. tostring(ns.db.combo) .. "\". Use /keebui combo target, player, bars or off.")
        end
    elseif msg:match("^font") then
        -- any font file by path, e.g. /keebui font Interface\\AddOns\\KeebUI\\Media\\MyFont.ttf
        local path = (msg ~= "font") and SlashCmdList.KEEBUI_RAW and SlashCmdList.KEEBUI_RAW:match("^%s*%a+%s+(.+)$")
        if path and path:lower() == "default" then
            ns.db.fontFace = nil
            ns.Print("font back to the default. Type /reload to apply.")
        elseif path then
            ns.db.fontFace = path
            ns.Print("font set to " .. path .. ". Type /reload to apply. If text looks unchanged, the file was not found.")
        else
            ns.Print("use /keebui font <path to a .ttf>, or /keebui font default. The settings window lists the built-in ones.")
        end
    elseif msg == "threat" then
        if ns.ToggleThreatWindow then ns.ToggleThreatWindow() end
    elseif msg == "click" or msg == "clickcast" or msg:match("^rightclick") then
        if ns.ToggleClickCast then ns.ToggleClickCast() end
    elseif msg == "frames" or msg == "raid" or msg == "party" then
        if ns.ToggleFrameOptions then ns.ToggleFrameOptions() end
    elseif msg == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("troubleshooting notes are " .. (ns.db.debug and "kept" or "no longer kept") .. " in the settings file.")
    elseif msg == "restore" then
        ns.RestoreOldUI()
    elseif msg == "welcome" or msg == "setup" then
        if ns.ShowWelcome then ns.ShowWelcome() end
    elseif msg == "move" or msg == "unlock" then
        ns.SetUnlocked(true)
    elseif msg == "lock" then
        ns.SetUnlocked(false)
    else
        ns.ToggleOptions()
    end
end
