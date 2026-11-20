-- KeebUI at the bank, for equipment sets:
--   * gear that belongs to a saved set is framed in the bank too, in that
--     set's colour (the same marks as in your bags)
--   * a small window opens with the bank: Deposit or Withdraw a whole set
--     with one click

local ADDON, ns = ...

local C = C_Container
local MOVE_INTERVAL = 0.1 -- seconds between item moves, so the server keeps up
local ROW = 26
local bankOpen = false
local ticker

---------------------------------------------------------------------------
-- Which containers are bags and which are the bank
---------------------------------------------------------------------------
local function InventoryBags()
    local bags = {}
    for bag = BACKPACK_CONTAINER or 0, NUM_BAG_SLOTS or 4 do bags[#bags + 1] = bag end
    return bags
end

local function BankBags()
    local bags, seen = {}, {}
    local function add(bag)
        if bag and not seen[bag] then
            seen[bag] = true
            bags[#bags + 1] = bag
        end
    end
    add(BANK_CONTAINER)
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
    local inv = Constants and Constants.InventoryConstants
    local count = NUM_BANKBAGSLOTS or (inv and inv.NumCharacterBankSlots) or 7
    for bag = first, first + count - 1 do add(bag) end
    local index = Enum and Enum.BagIndex
    if index then
        local i = 1
        while index["CharacterBankTab_" .. i] do
            add(index["CharacterBankTab_" .. i])
            i = i + 1
        end
    end
    return bags
end

-- empty slots in general-purpose containers, in order
local function FreeSlots(bags)
    local free = {}
    for _, bag in ipairs(bags) do
        local numFree, family = C.GetContainerNumFreeSlots(bag)
        if numFree and numFree > 0 and (family or 0) == 0 then
            for slot = 1, C.GetContainerNumSlots(bag) do
                if not C.GetContainerItemInfo(bag, slot) then free[#free + 1] = { bag, slot } end
            end
        end
    end
    return free
end

---------------------------------------------------------------------------
-- Moving a set
---------------------------------------------------------------------------
local function MoveSet(setID, deposit)
    local name = C_EquipmentSet.GetEquipmentSetInfo(setID) or "?"
    if not bankOpen then
        ns.Print("open your bank first.")
        return
    end
    if ticker then
        ns.Print("still moving items, one moment.")
        return
    end

    -- item id -> how many of it the set uses
    local need, total = {}, 0
    for _, itemID in pairs(C_EquipmentSet.GetItemIDs(setID) or {}) do
        if type(itemID) == "number" and itemID > 1 then
            need[itemID] = (need[itemID] or 0) + 1
            total = total + 1
        end
    end
    if total == 0 then
        ns.Print(("'%s' has no items in it."):format(name))
        return
    end

    local sources = deposit and InventoryBags() or BankBags()
    local free = FreeSlots(deposit and BankBags() or InventoryBags())
    local moves, noRoom = {}, 0
    for _, bag in ipairs(sources) do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local itemID = C.GetContainerItemID(bag, slot)
            if itemID and (need[itemID] or 0) > 0 then
                local info = C.GetContainerItemInfo(bag, slot)
                if not (info and info.isLocked) then
                    local dest = free[#moves + 1]
                    if dest then
                        need[itemID] = need[itemID] - 1
                        moves[#moves + 1] = { bag, slot, dest[1], dest[2] }
                    else
                        noRoom = noRoom + 1
                    end
                end
            end
        end
    end

    if noRoom > 0 then
        ns.Print(("not enough room in your %s: %d item(s) of '%s' left behind."):format(deposit and "bank" or "bags", noRoom, name))
    end
    if #moves == 0 then
        if noRoom == 0 then
            ns.Print(("nothing from '%s' found in your %s."):format(name, deposit and "bags" or "bank"))
        end
        return
    end
    ns.Print(("%s %d item(s) of '%s'."):format(deposit and "depositing" or "withdrawing", #moves, name))

    local i = 0
    ticker = C_Timer.NewTicker(MOVE_INTERVAL, function(self)
        i = i + 1
        local move = moves[i]
        if not move or not bankOpen then
            self:Cancel()
            ticker = nil
            return
        end
        ClearCursor()
        C.PickupContainerItem(move[1], move[2])
        C.PickupContainerItem(move[3], move[4])
        ClearCursor()
    end)
end

---------------------------------------------------------------------------
-- Set marks on the bank's own item buttons
---------------------------------------------------------------------------
local function MarkBank()
    local mark = ns.MarkSetItem
    if not mark then return end
    -- older-style bank window: BankFrameItem1, 2, ...
    for slot = 1, 200 do
        local button = _G["BankFrameItem" .. slot]
        if not button then break end
        mark(button, ns.Clean(C.GetContainerItemID(BANK_CONTAINER or -1, button:GetID())) or false)
    end
    -- newer-style bank window: a pool of buttons that know their own tab and slot
    local panel = _G.BankPanel
    local pool = panel and panel.itemButtonPool
    if pool and pool.EnumerateActive then
        for button in pool:EnumerateActive() do
            local bag = button.GetBankTabID and button:GetBankTabID()
            local slot = button.GetContainerSlotID and button:GetContainerSlotID()
            local id = bag and slot and ns.Clean(C.GetContainerItemID(bag, slot))
            mark(button, id or false)
        end
    end
end
local SafeMarkBank = ns.Safe("set gear highlight (bank)", MarkBank)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function TextButton(parent, width, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 20)
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local fill = b:CreateTexture(nil, "BORDER")
    fill:SetColorTexture(0.16, 0.18, 0.16, 1)
    fill:SetAllPoints()
    local shine = b:CreateTexture(nil, "HIGHLIGHT")
    shine:SetAllPoints()
    shine:SetColorTexture(1, 1, 1, 0.1)
    local label = ns.Text(b, 12, "CENTER")
    label:SetPoint("CENTER")
    label:SetText(text)
    return b
end

local function BuildWindow()
    local anchor = ns.Anchor("banksets", "Bank sets", 290, 60, 380, 520)
    local f = CreateFrame("Frame", nil, anchor)
    f:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    f:SetWidth(290)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:Hide()
    ns.Edge(f)
    local back = f:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.08, 0.09, 0.08, 0.95)
    local title = ns.Text(f, 13, "LEFT")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Equipment sets")
    title:SetTextColor(0.6, 0.63, 0.6)
    local empty = ns.Text(f, 12, "LEFT")
    empty:SetPoint("TOPLEFT", 10, -32)
    empty:SetText("No saved sets yet")
    empty:SetTextColor(0.5, 0.5, 0.5)

    local rows = {}
    local function Refresh()
        local ids = C_EquipmentSet.GetEquipmentSetIDs() or {}
        table.sort(ids)
        for i, setID in ipairs(ids) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, f)
                row:SetHeight(ROW)
                row:SetPoint("TOPLEFT", 10, -28 - (i - 1) * ROW)
                row:SetPoint("RIGHT", -10, 0)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT")
                row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                row.withdraw = TextButton(row, 66, "Withdraw")
                row.withdraw:SetPoint("RIGHT")
                row.withdraw:SetScript("OnClick", function() MoveSet(row.setID, false) end)
                row.deposit = TextButton(row, 60, "Deposit")
                row.deposit:SetPoint("RIGHT", row.withdraw, "LEFT", -5, 0)
                row.deposit:SetScript("OnClick", function() MoveSet(row.setID, true) end)
                row.name = ns.Text(row, 13, "LEFT")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
                row.name:SetPoint("RIGHT", row.deposit, "LEFT", -5, 0)
                rows[i] = row
            end
            local name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
            row.setID = setID
            row.name:SetText(name or "?")
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row:Show()
        end
        for i = #ids + 1, #rows do rows[i]:Hide() end
        empty:SetShown(#ids == 0)
        f:SetHeight(36 + math.max(#ids, 1) * ROW)
    end
    f:SetScript("OnShow", ns.Safe("bank sets window", Refresh))
    f.Refresh = Refresh
    return f
end

local function Init()
    if not (C and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then return end

    -- the user's own SetBanker addon does the same job; do not show two windows
    local own = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SetBanker")
    local window
    if not own then
        local ok, made = pcall(BuildWindow)
        if ok then window = made else ns.LogError("bank sets window", made) end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("BANKFRAME_OPENED")
    events:RegisterEvent("BANKFRAME_CLOSED")
    events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    pcall(events.RegisterEvent, events, "PLAYERBANKSLOTS_CHANGED")
    events:SetScript("OnEvent", ns.Safe("bank sets", function(_, event)
        if event == "BANKFRAME_OPENED" then
            bankOpen = true
            if window then window:Show() end
            SafeMarkBank()
            C_Timer.After(0.3, SafeMarkBank) -- once the bank's buttons are filled in
        elseif event == "BANKFRAME_CLOSED" then
            bankOpen = false
            if window then window:Hide() end
        elseif bankOpen then
            if event == "EQUIPMENT_SETS_CHANGED" and window and window:IsShown() then window.Refresh() end
            C_Timer.After(0.1, SafeMarkBank)
        end
    end))
end

ns.modules[#ns.modules + 1] = { setting = "chrome", init = Init }
