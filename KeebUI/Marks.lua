-- KeebUI raid tools.
--
-- 1. Mark ring: hold a key and a ring of raid marks pops up at the cursor,
--    skull in the middle. Let go over a mark to put it on YOUR TARGET (never
--    on whatever the mouse happens to be over). A quick tap is skull. Let go
--    outside the ring to cancel. Bind it under Key Bindings > AddOns > KeebUI.
--
-- 2. A small bar, shown while you are in a group: ready check, pull timer,
--    and the eight marks (again for your target) plus clear.
--
-- Marking is something only the game's own secure buttons may do on this
-- client, so both pieces are built from those; this file's ordinary code
-- only draws the ring's highlight.

local ADDON, ns = ...

_G["BINDING_NAME_CLICK KeebUIMarkKey:LeftButton"] = "Raid mark ring (tap = skull)"

local ICON_SIZE = 34
local RADIUS = 58                        -- distance of the outer icons from the centre
local SIZE = (RADIUS + ICON_SIZE) * 2    -- the ring's box; letting go outside it cancels
local CENTER_R = RADIUS / 2              -- inside this = skull
local CENTER = 8
local RING = { 7, 6, 5, 4, 3, 2, 1, 0 }  -- cross, square, moon, triangle, diamond, circle, star, clear
local NAMES = { [0] = "Clear", "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

local function IconPath(index)
    if index == 0 then return "Interface\\Buttons\\UI-GroupLoot-Pass-Up" end
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end

---------------------------------------------------------------------------
-- Mark ring
---------------------------------------------------------------------------
local function InitRing()
    local offsets = {}
    for i, index in ipairs(RING) do
        local angle = math.rad(90 - (i - 1) * (360 / #RING))
        offsets[i] = { index, math.cos(angle) * RADIUS, math.sin(angle) * RADIUS }
    end

    -- a full-screen secure frame, so the secure code can ask where the cursor is
    local screen = CreateFrame("Frame", "KeebUIMarkScreen", UIParent, "SecureHandlerBaseTemplate")
    screen:SetAllPoints(UIParent)

    local ring = CreateFrame("Frame", "KeebUIMarkRing", UIParent, "SecureHandlerBaseTemplate")
    ring:SetSize(SIZE, SIZE)
    ring:SetFrameStrata("TOOLTIP")
    ring:SetPoint("CENTER")
    ring:Hide()
    ring:SetFrameRef("screen", screen)

    local disc = ring:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture("Interface\\Buttons\\WHITE8x8")
    disc:SetPoint("CENTER")
    disc:SetSize(RADIUS * 2 + ICON_SIZE * 1.4, RADIUS * 2 + ICON_SIZE * 1.4)
    disc:SetVertexColor(0.05, 0.06, 0.05, 0.7)
    local mask = ring:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(disc)
    disc:AddMaskTexture(mask)

    local label = ns.Text(ring, 15, "CENTER")
    label:SetPoint("TOP", disc, "BOTTOM", 0, -2)

    local icons = {}
    local function MakeIcon(index, x, y)
        local tex = ring:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER", ring, "CENTER", x, y)
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetTexture(IconPath(index))
        tex:SetAlpha(0.55)
        icons[#icons + 1] = { index = index, tex = tex }
    end
    MakeIcon(CENTER, 0, 0)
    for _, o in ipairs(offsets) do MakeIcon(o[1], o[2], o[3]) end

    -- the key: a secure raid-target button the keybind presses and releases
    local key = CreateFrame("Button", "KeebUIMarkKey", UIParent, "SecureActionButtonTemplate")
    key:RegisterForClicks("AnyDown", "AnyUp")
    key:SetAttribute("type", "raidtarget")
    key:SetAttribute("useOnKeyDown", false) -- act on release
    key:SetAttribute("unit", "target")
    key:SetAttribute("marker", CENTER)
    key:SetAttribute("action", "toggle")

    local nearest = {}
    for _, o in ipairs(offsets) do
        nearest[#nearest + 1] = ("d = (dx - %.2f)^2 + (dy - %.2f)^2; if d < best then best, mark = d, %d end")
            :format(o[2], o[3], o[1])
    end

    -- Runs in the game's secure environment on key down and key up.
    -- Returning false stops the button from doing anything.
    local snippet = ([[
        if down then
            if not UnitExists("target") then return false end
            local screen = owner:GetFrameRef("screen")
            local mx, my = screen:GetMousePosition()
            if not mx then return false end
            owner:ClearAllPoints()
            owner:SetPoint("CENTER", screen, "BOTTOMLEFT", mx * screen:GetWidth(), my * screen:GetHeight())
            owner:Show()
            return false
        end

        if not owner:IsShown() then return false end
        local mx, my = owner:GetMousePosition()
        owner:Hide()
        if not mx or not UnitExists("target") then return false end

        local dx = (mx - 0.5) * owner:GetWidth()
        local dy = (my - 0.5) * owner:GetHeight()
        local mark = %d
        if dx * dx + dy * dy > %.2f then
            local best, d = 1e9, 0
            %s
        end
        self:SetAttribute("unit", "target")
        if mark == 0 then
            self:SetAttribute("action", "clear")
        else
            self:SetAttribute("action", "toggle")
            self:SetAttribute("marker", mark)
        end
    ]]):format(CENTER, CENTER_R * CENTER_R, table.concat(nearest, "\n            "))
    SecureHandlerWrapScript(key, "OnClick", ring, snippet)

    -- which mark the cursor is nearest: bright and a little larger, the rest dim
    local shown
    local function Highlight(i)
        if shown == i then return end
        if shown then
            icons[shown].tex:SetAlpha(0.55)
            icons[shown].tex:SetSize(ICON_SIZE, ICON_SIZE)
        end
        shown = i
        if i then
            icons[i].tex:SetAlpha(1)
            icons[i].tex:SetSize(ICON_SIZE * 1.25, ICON_SIZE * 1.25)
            label:SetText(NAMES[icons[i].index])
        else
            label:SetText("|cff999999Cancel|r")
        end
    end
    ring:SetScript("OnUpdate", function(self)
        local ok, l, b, w, h = pcall(self.GetRect, self)
        if not ok or not l then return end
        local s = self:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / s, y / s
        if x < l or x > l + w or y < b or y > b + h then
            Highlight(nil)
            return
        end
        local dx, dy = x - (l + w / 2), y - (b + h / 2)
        if dx * dx + dy * dy <= CENTER_R * CENTER_R then
            Highlight(1)
            return
        end
        local best, pick = math.huge, 2
        for i, o in ipairs(offsets) do
            local d = (dx - o[2]) ^ 2 + (dy - o[3]) ^ 2
            if d < best then best, pick = d, i + 1 end
        end
        Highlight(pick)
    end)
    ring:SetScript("OnHide", function()
        Highlight(nil)
        shown = nil
    end)
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
local function InitBar()
    local MARK, GAP, TEXT_W, HEIGHT = 22, 3, 58, 22
    local width = 2 * (TEXT_W + GAP) + 9 * (MARK + GAP) - GAP
    local top = (UIParent:GetHeight() or 768) - 22
    local anchor = ns.Anchor("raidtools", "Raid tools", width, HEIGHT, 0, top)

    -- a secure frame, so the game can show and hide it (in a group / not) even in combat
    local bar = CreateFrame("Frame", "KeebUIRaidTools", anchor, "SecureHandlerStateTemplate")
    bar:SetAllPoints(anchor)
    -- Shown while you are in a group, except in battlegrounds and arenas:
    -- the score display sits at the top of the screen there, and ready checks
    -- and pull timers have no use. The rule can only be changed out of
    -- combat, so a change that comes up mid-fight waits for the fight to end.
    local rule
    local function SetRule()
        local inInstance, kind = IsInInstance()
        local want = (inInstance and (kind == "pvp" or kind == "arena")) and "hide" or "[group] show; hide"
        if want == rule or InCombatLockdown() then return end
        rule = want
        RegisterStateDriver(bar, "visibility", want)
    end
    SetRule()
    local zone = CreateFrame("Frame")
    zone:RegisterEvent("PLAYER_ENTERING_WORLD")
    zone:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zone:RegisterEvent("PLAYER_REGEN_ENABLED")
    zone:SetScript("OnEvent", ns.Safe("raid tools bar", SetRule))

    local x = 0
    local function Slot(w)
        local b = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
        b:SetSize(w, HEIGHT)
        b:SetPoint("LEFT", x, 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        x = x + w + GAP
        local edge = b:CreateTexture(nil, "BACKGROUND")
        edge:SetColorTexture(0, 0, 0, 1)
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        local fill = b:CreateTexture(nil, "BORDER")
        fill:SetColorTexture(0.13, 0.15, 0.13, 1)
        fill:SetAllPoints()
        local shine = b:CreateTexture(nil, "HIGHLIGHT")
        shine:SetAllPoints()
        shine:SetColorTexture(1, 1, 1, 0.12)
        return b
    end
    local function Tip(b, title, line)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(title)
            if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local ready = Slot(TEXT_W)
    ready:SetAttribute("type", "macro")
    ready:SetAttribute("macrotext", "/readycheck")
    local readyText = ns.Text(ready, 12, "CENTER")
    readyText:SetPoint("CENTER")
    readyText:SetText("Ready")
    Tip(ready, "Ready check", "Needs leader or assistant.")

    local pull = Slot(TEXT_W)
    pull:SetAttribute("type", "macro")
    pull:SetAttribute("macrotext1", "/countdown 10")
    pull:SetAttribute("macrotext2", "/countdown 0")
    local pullText = ns.Text(pull, 12, "CENTER")
    pullText:SetPoint("CENTER")
    pullText:SetText("Pull 10")
    Tip(pull, "Pull timer", "Left-click: 10 second countdown. Right-click: cancel.")

    for _, index in ipairs({ 8, 7, 6, 5, 4, 3, 2, 1, 0 }) do
        local b = Slot(MARK)
        b:SetAttribute("type", "raidtarget")
        b:SetAttribute("unit", "target")
        if index == 0 then
            b:SetAttribute("action", "clear")
        else
            b:SetAttribute("action", "toggle")
            b:SetAttribute("marker", index)
        end
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexture(IconPath(index))
        Tip(b, NAMES[index], index == 0 and "Clear your target's mark." or "Mark your target.")
    end

    -- quiet until the mouse is on it
    bar:SetAlpha(0.35)
    local watch = CreateFrame("Frame", nil, anchor)
    local wait = 0
    watch:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + elapsed
        if wait < 0.1 then return end
        wait = 0
        if bar:IsShown() then bar:SetAlpha(bar:IsMouseOver() and 1 or 0.35) end
    end)
end

local function Init()
    if InCombatLockdown() then return end -- secure frames cannot be made in combat; next login
    local ok, err = pcall(InitRing)
    if not ok then ns.LogError("mark ring", err) end
    ok, err = pcall(InitBar)
    if not ok then ns.LogError("raid tools bar", err) end
end

ns.modules[#ns.modules + 1] = { setting = "raidTools", init = Init }
