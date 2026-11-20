-- KeebUI skin: flat tooltips (plain dark panel with a thin black edge, slim
-- flat health bar). Chat is left exactly as the game draws it.
--
-- Tooltips are touchy: the game refuses to show some of their contents if an
-- addon has been meddling inside them. So nothing here runs while a tooltip
-- is being filled in: the flat panel is added once, up front, as a separate
-- layer behind the text, and the stock border is simply made invisible.

local ADDON, ns = ...

local function FlatTooltip(tip)
    if not tip or tip.keebFlat then return end
    tip.keebFlat = true
    local slice = tip.NineSlice
    if slice and slice.SetAlpha then slice:SetAlpha(0) end

    local back = CreateFrame("Frame", nil, tip)
    back:SetFrameLevel(math.max(tip:GetFrameLevel() - 1, 0))
    back:SetPoint("TOPLEFT", 2, -2)
    back:SetPoint("BOTTOMRIGHT", -2, 2)
    local edge = back:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    local fill = back:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetColorTexture(0.07, 0.08, 0.07, 0.95)
end

local function InitTooltips()
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
        "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "WorldMapTooltip" }) do
        local ok, err = pcall(FlatTooltip, _G[name])
        if not ok then ns.LogError("flat tooltip " .. name, err) end
    end

    -- the health bar under unit tooltips
    local bar = GameTooltipStatusBar
    if bar and bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(ns.TEX)
        bar:SetHeight(4)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 3, 3)
        bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -3, 3)
    end
end

local function Init()
    local ok, err = pcall(InitTooltips)
    if not ok then ns.LogError("flat tooltips", err) end
end

ns.modules[#ns.modules + 1] = { setting = "skin", init = Init }
