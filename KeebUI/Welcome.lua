-- KeebUI welcome screen. Shown on the first login after installing: nothing
-- about your interface is changed until you choose what you want here and
-- press Apply. "/keebui welcome" brings it back any time.

local ADDON, ns = ...

local GOLD = { 0.95, 0.76, 0.19 }
local WIDTH, ROW = 460, 40
local window

local function Flat(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function Button(parent, width, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 26)
    local edge = Flat(b, 0, 0, 0, 1, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.fill = Flat(b, 0.16, 0.18, 0.16, 1, "BORDER")
    b.fill:SetAllPoints()
    local shine = b:CreateTexture(nil, "HIGHLIGHT")
    shine:SetAllPoints()
    shine:SetColorTexture(1, 1, 1, 0.08)
    b.label = ns.Text(b, 14, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    return b
end

-- If the screen is narrower than the layout was drawn for, start the frames
-- a little smaller so the player and target frames keep clear of the edges.
local function FitScale()
    local width = UIParent:GetWidth() or 1366
    if width < 1150 and (ns.db.scale or 1) == 1 then
        ns.db.scale = math.max(0.7, math.floor(width / 1150 * 20 + 0.5) / 20)
    end
end

local function Build()
    local pieces = ns.PIECES
    local f = CreateFrame("Frame", "KeebUIWelcome", UIParent)
    f:SetSize(WIDTH, 96 + #pieces * ROW + 70)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local edge = Flat(f, 0, 0, 0, 1, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local back = Flat(f, 0.08, 0.09, 0.08, 0.97, "BORDER")
    back:SetAllPoints()

    local title = ns.Text(f, 20, "LEFT")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText("KeebUI")
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local intro = ns.Text(f, 13, "LEFT")
    intro:SetPoint("TOPLEFT", 20, -46)
    intro:SetPoint("RIGHT", -20, 0)
    intro:SetWordWrap(true)
    intro:SetTextColor(0.75, 0.78, 0.75)
    intro:SetText("Nothing has been changed yet. Pick the pieces you want; keybinds and what is on your bars are never touched, and \"Restore my old UI\" in /keebui undoes all of it.")

    local chosen = {}
    for n, piece in ipairs(pieces) do
        chosen[n] = true
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW - 4)
        row:SetPoint("TOPLEFT", 20, -96 - (n - 1) * ROW)
        row:SetPoint("RIGHT", -20, 0)
        local shine = row:CreateTexture(nil, "HIGHLIGHT")
        shine:SetAllPoints()
        shine:SetColorTexture(1, 1, 1, 0.05)
        local rim = Flat(row, 0, 0, 0, 1, "BACKGROUND")
        rim:SetSize(18, 18)
        rim:SetPoint("LEFT", 2, 0)
        local box = Flat(row, 0.16, 0.18, 0.16, 1, "BORDER")
        box:SetPoint("TOPLEFT", rim, 1, -1)
        box:SetPoint("BOTTOMRIGHT", rim, -1, 1)
        local tick = Flat(row, GOLD[1], GOLD[2], GOLD[3], 1, "ARTWORK")
        tick:SetPoint("TOPLEFT", rim, 4, -4)
        tick:SetPoint("BOTTOMRIGHT", rim, -4, 4)
        local label = ns.Text(row, 14, "LEFT")
        label:SetPoint("TOPLEFT", rim, "TOPRIGHT", 10, piece[2] ~= "" and 4 or -1)
        label:SetText(piece[1])
        if piece[2] ~= "" then
            local note = ns.Text(row, 12, "LEFT")
            note:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
            note:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            note:SetTextColor(0.55, 0.58, 0.55)
            note:SetText(piece[2])
        end
        row:SetScript("OnClick", function()
            chosen[n] = not chosen[n]
            tick:SetShown(chosen[n])
        end)
    end

    local apply = Button(f, 150, "Apply and reload")
    apply.fill:SetColorTexture(GOLD[1] * 0.75, GOLD[2] * 0.75, GOLD[3] * 0.75, 1)
    apply:SetPoint("BOTTOMRIGHT", -20, 18)
    apply:SetScript("OnClick", function()
        if InCombatLockdown() then
            ns.Print("can't do that in combat.")
            return
        end
        for n, piece in ipairs(pieces) do
            for _, key in ipairs(piece[3]) do ns.db[key] = chosen[n] end
        end
        pcall(FitScale)
        ns.db.setupDone = true
        ReloadUI()
    end)
    local later = Button(f, 100, "Not now")
    later:SetPoint("RIGHT", apply, "LEFT", -10, 0)
    later:SetScript("OnClick", function()
        f:Hide()
        ns.Print("nothing was changed. Type /keebui welcome when you want to set it up.")
    end)
    return f
end

function ns.ShowWelcome()
    if not window then
        local ok, made = pcall(Build)
        if not ok then
            ns.LogError("welcome screen", made)
            return
        end
        window = made
    end
    window:Show()
end
