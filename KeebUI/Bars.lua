-- KeebUI action bars: the built-in buttons, restyled where they stand.
-- Nothing is replaced, so keybinds, button contents and paging are exactly
-- what they were. Each button gets softly rounded corners and a thin dark rim.

local ADDON, ns = ...

local BARS = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "MultiBar5Button", 12 },
    { "MultiBar6Button", 12 },
    { "MultiBar7Button", 12 },
    { "PetActionButton", 10 },
    { "StanceButton", 10 },
}

local MASK = ns.MEDIA .. "Mask"
local RIM = ns.MEDIA .. "Border"

local extras = setmetatable({}, { __mode = "k" }) -- button -> things we added

-- Flat colour over the whole button, clipped to the rounded shape.
local function Flat(texture, button, added, r, g, b, a)
    if not texture then return end
    texture:SetColorTexture(r, g, b, a)
    texture:ClearAllPoints()
    texture:SetAllPoints(button)
    if not added.masked[texture] and texture.AddMaskTexture then
        added.masked[texture] = true
        texture:AddMaskTexture(added.mask)
    end
end

local function Apply(button)
    local name = button:GetName()
    local icon = button.icon or (name and _G[name .. "Icon"])
    if not icon then return end

    local added = extras[button]
    if not added then
        added = { masked = {} }
        extras[button] = added

        added.mask = button:CreateMaskTexture()
        added.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        added.mask:SetAllPoints(button)

        added.bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        added.bg:SetAllPoints()
        added.bg:SetColorTexture(0.08, 0.08, 0.08, 0.75)
        added.bg:AddMaskTexture(added.mask)

        -- rounded rim on its own layer above the icon and the cooldown sweep
        local top = CreateFrame("Frame", nil, button)
        top:SetAllPoints()
        top:SetFrameLevel(button:GetFrameLevel() + 3)
        added.rim = top:CreateTexture(nil, "OVERLAY")
        added.rim:SetTexture(RIM)
        added.rim:SetVertexColor(0, 0, 0, 0.9)
        added.rim:SetAllPoints()
    end

    -- stock frame art off
    local normal = button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture())
    if normal then normal:SetAlpha(0) end
    for _, key in ipairs({ "SlotArt", "SlotBackground", "FloatingBG", "RightDivider", "BottomDivider" }) do
        local art = button[key]
        if art and art.SetAlpha then art:SetAlpha(0) end
    end
    if button.IconMask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(button.IconMask) end

    -- icon fills the button, corners rounded
    -- Icon art is only 64 pixels square, about what a button covers on screen,
    -- so every bit that is cropped away gets stretched back and blurs it. Trim
    -- just the art's own bevelled edge, and keep the texture on whole pixels.
    icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    if icon.SetSnapToPixelGrid then
        icon:SetSnapToPixelGrid(true)
        icon:SetTexelSnappingBias(0)
    end
    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    if not added.masked[icon] and icon.AddMaskTexture then
        added.masked[icon] = true
        icon:AddMaskTexture(added.mask)
    end

    -- flat pressed / hover / active states
    Flat(button.GetPushedTexture and button:GetPushedTexture(), button, added, 1, 1, 1, 0.25)
    Flat(button.GetHighlightTexture and button:GetHighlightTexture(), button, added, 1, 1, 1, 0.15)
    Flat(button.GetCheckedTexture and button:GetCheckedTexture(), button, added, 1, 0.9, 0.4, 0.3)

    local cooldown = button.cooldown or (name and _G[name .. "Cooldown"])
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button)
        if cooldown.SetSwipeTexture and not added.swipe then
            added.swipe = true
            pcall(cooldown.SetSwipeTexture, cooldown, MASK)
            if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.75) end
        end
    end

    -- text: same easy-to-read face as the cast bar
    local hotkey = button.HotKey or (name and _G[name .. "HotKey"])
    if hotkey then
        -- big, pure white, heavy black outline: readable on any icon
        if not hotkey:SetFont(ns.FONT, 16, "THICKOUTLINE") then
            hotkey:SetFont(STANDARD_TEXT_FONT, 15, "THICKOUTLINE")
        end
        hotkey:SetShadowColor(0, 0, 0, 1)
        hotkey:SetShadowOffset(1, -1)
        if not added.hotkeyHooked then
            added.hotkeyHooked = true
            -- The game tints keybinds a dull grey when in range (and red when
            -- out of range). Grey becomes white; the red warning is kept.
            local busy = false
            hooksecurefunc(hotkey, "SetVertexColor", function(self, r, g, b)
                if busy or ns.IsSecret(r) or type(r) ~= "number" then return end
                if r == g and g == b and r < 1 then
                    busy = true
                    self:SetVertexColor(1, 1, 1)
                    busy = false
                end
            end)
            hotkey:SetVertexColor(1, 1, 1)
        end
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -3)
        -- "s-1" reads cleaner as "S1"
        local text = hotkey:GetText()
        if type(text) == "string" and not ns.IsSecret(text) then
            local short = text:gsub("^s%-", "S"):gsub("^c%-", "C"):gsub("^a%-", "A")
            if short ~= text then hotkey:SetText(short) end
        end
    end
    local count = button.Count or (name and _G[name .. "Count"])
    if count then
        ns.SetFont(count, 14)
        count:SetShadowColor(0, 0, 0, 1)
        count:SetShadowOffset(1, -1)
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end
    local macro = button.Name or (name and _G[name .. "Name"])
    if macro then
        ns.SetFont(macro, 11)
    end
end

local SafeApply = ns.Safe("action button", Apply)

local function Init()
    for _, bar in ipairs(BARS) do
        for i = 1, bar[2] do
            local button = _G[bar[1] .. i]
            if button then
                SafeApply(button)
                -- the game redraws its art now and then; put ours back afterwards
                if button.UpdateButtonArt then
                    hooksecurefunc(button, "UpdateButtonArt", SafeApply)
                end
                if button.UpdateHotkeys then
                    hooksecurefunc(button, "UpdateHotkeys", SafeApply)
                end
            end
        end
    end

    -- gryphons and the bar's frame art
    local main = MainActionBar or MainMenuBar
    if main then
        if main.EndCaps then main.EndCaps:SetAlpha(0) end
        if main.BorderArt then main.BorderArt:SetAlpha(0) end
        -- the page number with its up/down arrows beside the bar: invisible and
        -- not clickable (the Edit Mode layout also switches it off)
        local pager = main.ActionBarPageNumber
        if pager then
            pager:SetAlpha(0)
            for _, part in ipairs({ pager, pager.UpButton, pager.DownButton }) do
                if part and part.EnableMouse and not InCombatLockdown() then part:EnableMouse(false) end
            end
        end
    end

    local again = CreateFrame("Frame")
    again:RegisterEvent("PLAYER_ENTERING_WORLD")
    again:SetScript("OnEvent", function()
        for button in pairs(extras) do SafeApply(button) end
    end)
end

ns.modules[#ns.modules + 1] = { setting = "bars", init = Init }
