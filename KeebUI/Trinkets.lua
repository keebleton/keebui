-- KeebUI trinkets: two buttons for your equipped trinkets, with a pop-up list
-- of the trinkets in your bags.
--   left-click a button      use that trinket (works in combat)
--   hover a button           list the trinkets in your bags above it
--   click one in the list    equip it into that slot; in combat it is queued
--                            (gold edge) and swapped in when combat ends
--   right-click a button     cancel a queued swap
-- Deliberately small: no automatic rotation, profiles or alerts.

local ADDON, ns = ...
local Clean = ns.Clean

local SIZE, GAP = 36, 3
local SLOTS = { 13, 14 }
local MASK = ns.MEDIA .. "Mask"
local RIM = ns.MEDIA .. "Border"

BINDING_HEADER_KEEBUI = "KeebUI"
_G["BINDING_NAME_CLICK KeebUITrinket13:LeftButton"] = "Use top trinket"
_G["BINDING_NAME_CLICK KeebUITrinket14:LeftButton"] = "Use bottom trinket"

-- icon, rounded like the action buttons, with a cooldown sweep
local function Dress(button)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.08, 0.08, 0.08, 0.75)
    back:AddMaskTexture(mask)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    button.icon:AddMaskTexture(mask)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawEdge(false)
    pcall(button.cooldown.SetSwipeTexture, button.cooldown, MASK)
    local top = CreateFrame("Frame", nil, button)
    top:SetAllPoints()
    top:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
    button.rim = top:CreateTexture(nil, "OVERLAY")
    button.rim:SetTexture(RIM)
    button.rim:SetVertexColor(0, 0, 0, 0.9)
    button.rim:SetAllPoints()
    local shine = button:CreateTexture(nil, "HIGHLIGHT")
    shine:SetAllPoints()
    shine:SetColorTexture(1, 1, 1, 0.15)
    shine:AddMaskTexture(mask)
end

local function SetSweep(cooldown, start, duration)
    start, duration = Clean(start), Clean(duration)
    if start and duration and start > 0 and duration > 1.5 then
        cooldown:SetCooldown(start, duration)
    else
        cooldown:Clear()
    end
end

-- every trinket in the bags: { id, bag, slot, icon }
local function BagTrinkets()
    local list = {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return list end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local id = Clean(C.GetContainerItemID(bag, slot))
            if id and instant then
                local _, _, _, where, icon = instant(id)
                if where == "INVTYPE_TRINKET" then
                    list[#list + 1] = { id = id, bag = bag, slot = slot, icon = icon }
                end
            end
        end
    end
    return list
end

local function Init()
    local width = #SLOTS * SIZE + (#SLOTS - 1) * GAP
    local half = (ns.STACK_WIDTH or 519) / 2
    -- default spot: left of the bottom row of the action bars
    local anchor = ns.Anchor("trinkets", "Trinkets", width, SIZE, -half - 10 - width / 2, 18 + SIZE / 2)

    local buttons, queued = {}, {} -- queued[slot] = item id waiting for combat to end
    local Refresh

    -- swap a bag trinket into a slot (never in combat: the game forbids it)
    local function EquipNow(slot, entry)
        if CursorHasItem() then return end
        C_Container.PickupContainerItem(entry.bag, entry.slot)
        PickupInventoryItem(slot)
        if CursorHasItem() then ClearCursor() end
    end

    local function Equip(slot, entry)
        if InCombatLockdown() then
            queued[slot] = entry.id
        else
            queued[slot] = nil
            local ok, err = pcall(EquipNow, slot, entry)
            if not ok then ns.LogError("trinket swap", err) end
        end
        Refresh()
    end

    -----------------------------------------------------------------------
    -- the pop-up list
    -----------------------------------------------------------------------
    local flyout = CreateFrame("Frame", nil, UIParent)
    flyout:SetFrameStrata("HIGH")
    flyout:Hide()
    local rows = {}

    local function OpenFlyout(owner)
        local list = BagTrinkets()
        flyout.owner = owner
        if #list == 0 then
            flyout:Hide()
            return
        end
        for i, entry in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", nil, flyout)
                row:SetSize(SIZE, SIZE)
                Dress(row)
                row:SetScript("OnClick", function(self)
                    if flyout.owner and self.entry then Equip(flyout.owner.slot, self.entry) end
                    flyout:Hide()
                end)
                row:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if pcall(GameTooltip.SetBagItem, GameTooltip, self.entry.bag, self.entry.slot) then GameTooltip:Show() end
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[i] = row
            end
            row.entry = entry
            row.icon:SetTexture(entry.icon)
            local getCooldown = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
            if getCooldown then SetSweep(row.cooldown, getCooldown(entry.id)) end
            row:ClearAllPoints()
            row:SetPoint("BOTTOM", flyout, "BOTTOM", 0, (i - 1) * (SIZE + GAP))
            row:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        flyout:SetSize(SIZE, #list * (SIZE + GAP))
        flyout:ClearAllPoints()
        flyout:SetPoint("BOTTOM", owner, "TOP", 0, GAP)
        flyout.away = 0
        flyout:Show()
    end

    -- closes a moment after the mouse leaves both the list and its button
    flyout:SetScript("OnUpdate", function(self, elapsed)
        local over = self:IsMouseOver(GAP, -GAP * 2, -GAP, GAP) or (self.owner and self.owner:IsMouseOver())
        if over then
            self.away = 0
        else
            self.away = (self.away or 0) + elapsed
            if self.away > 0.3 then self:Hide() end
        end
    end)

    -----------------------------------------------------------------------
    -- the two slot buttons
    -----------------------------------------------------------------------
    for i, slot in ipairs(SLOTS) do
        local b = CreateFrame("Button", "KeebUITrinket" .. slot, anchor, "SecureActionButtonTemplate")
        b.slot = slot
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        -- "*type1": only the left button uses the trinket, with or without modifiers
        b:SetAttribute("*type1", "macro")
        b:SetAttribute("*macrotext1", "/use " .. slot)
        Dress(b)
        b.queuedEdge = b:CreateTexture(nil, "OVERLAY", nil, 7)
        b.queuedEdge:SetTexture(RIM)
        b.queuedEdge:SetVertexColor(1, 0.8, 0.1, 1)
        b.queuedEdge:SetAllPoints()
        b.queuedEdge:Hide()
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", slot) then GameTooltip:Show() end
            ns.Safe("trinket list", OpenFlyout)(self)
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        b:HookScript("OnClick", function(_, mouse, down)
            if mouse == "RightButton" and not down and queued[slot] then
                queued[slot] = nil
                Refresh()
            end
        end)
        buttons[slot] = b
    end

    Refresh = ns.Safe("trinkets", function()
        for slot, b in pairs(buttons) do
            b.icon:SetTexture(GetInventoryItemTexture("player", slot))
            SetSweep(b.cooldown, GetInventoryItemCooldown("player", slot))
            b.queuedEdge:SetShown(queued[slot] ~= nil)
        end
    end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
        "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", ns.Safe("trinkets", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and next(queued) then
            -- combat is over: carry out the queued swaps
            local bags = BagTrinkets()
            for slot, id in pairs(queued) do
                queued[slot] = nil
                for _, entry in ipairs(bags) do
                    if entry.id == id then
                        pcall(EquipNow, slot, entry)
                        break
                    end
                end
            end
        end
        Refresh()
    end))
    Refresh()
end

ns.modules[#ns.modules + 1] = { setting = "trinkets", init = Init }
