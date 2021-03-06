-----------------------------------------------------------------------------------
-- Library Name: LibLazyCrafting (LLC)
-- Creator: Dolgubon (Joseph Heinzle)
-- Library Ideal: Allow addons to craft anything, anywhere
-- Library Creation Date: December, 2016
-- Publication Date: Febuary 5, 2017
--
-- File Name: LibLazyCrafting.lua
-- File Description: Contains the main functions of LLC, uncluding the queue and initialization functions
-- Load Order Requirements: Before all other library files
--
-----------------------------------------------------------------------------------

local function dbug(...)
    --DolgubonDebugRunningDebugString(...)
end

-- Initialize libraries
local libName, libVersion = "LibLazyCrafting", 2999
local libLoaded
local lib, oldminor
if(not LibStub) then
    lib = {}
else
    lib, oldminor = LibStub:NewLibrary(libName, libVersion)
    if not lib then
        return -- already loaded and no upgrade necessary
    end
end
if not lib then return end

_G["lib_global"] = lib

local LLC_SHORT = lib -- Short form version we can use if needed

LLC_SHORT.name, LLC_SHORT.version = libName, libVersion

LLC_SHORT.debugDisplayNames = {}

lib.craftInteractionTables = lib.craftInteractionTables or
{
    ["example"] =
    {
        ["check"] = function(self, station) if station == 123 then return false end end,
        ["function"] = function(station) --[[craftStuff()]] end,
        ["complete"] = function(station) --[[handleCraftCompletion()]] end,
        ["endInteract"] = function(self, station) --[[endInteraction()]] end,
    }
}

lib.isCurrentlyCrafting = {false, "", ""}
LLC_SHORT.widgets = LLC_SHORT.widgets or {['initializers'] = {}}
local widgets = LLC_SHORT.widgets

--METHOD: REGISTER WIDGET--
--each widget has its version checked before loading,
--so we only have the most recent one in memory
--Usage:
--  widgetType = "string"; the type of widget being registered
--  widgetVersion = integer; the widget's version number
--  From LibAddonMenu

function lib:RegisterWidget(widgetType, widgetVersion)
    if widgets[widgetType] and widgets[widgetType] >= widgetVersion then
        return false
    else
        widgets[widgetType] = widgetVersion
        return true
    end
end

local queuePosition = 0
function lib.GetNextQueueOrder()
    queuePosition = queuePosition + 1
    return queuePosition
end

-- -- Re initialize crafts if this run of the library overwrote a previous one.
-- if oldVersion then
--  for k, reInitialize in pairs(LLC_SHORT.widgets.initializers) do
--      reInitialize()
--  end
-- end


-- Index starts at 0 because that's how many upgrades are needed.
local qualityIndexes =
{
    [0] = "White",
    [1] = "Green",
    [2] = "Blue",
    [3] = "Epic",
    [4] = "Gold",
}


-- Crafting request Queue. Split by addon. Further split by station. Each request has a timestamp for when it was requested.
-- Due to how requests are added, each addon's requests withing station should be sorted by oldest to newest. We'll assume that. (maybe check once in a while)
-- Thus, all that's needed to find the oldest request is cycle through each addon, and check only their first request.
-- Unless a user has hundreds of addons using this library (unlikely) it shouldn't be a big strain. (shouldn't anyway)
-- Not sure how to handle multiple stations for furniture. needs more research for that.
craftingQueue = craftingQueue or
{
    --["GenericTesting"] = {}, -- This is for say, calling from chat.
    ["ExampleAddon"] = -- This contains examples of all the crafting requests. It is removed upon initialization. Most values are random/default.
    {
        ["autocraft"] = false, -- if true, then timestamps will be applied when the addon calls LLC_craft()
        [CRAFTING_TYPE_CLOTHIER] = {},
        [CRAFTING_TYPE_JEWELRYCRAFTING] = {},
        [CRAFTING_TYPE_WOODWORKING] =
        {
            {["type"] = "smithing",
            ["pattern"] =0,
            ["Requester"] = "",
            ["autocraft"] = true,
            ["style"] = 0,
            ["trait"] = 0,
            ["materialIndex"] = 0,
            ["materialQuantity"] = 0,
            ["setIndex"] = 0,
            ["quality"] = 0,
            ["useUniversalStyleItem"] = false,
            ["timestamp"] = 1111113223232323231, },
        },
        [CRAFTING_TYPE_BLACKSMITHING] =
        {
            {["type"] = "improvement",
            ["Requester"] = "", -- ADDON NAME
            ["autocraft"] = true,
            ["ItemLink"] = "",
            ["ItemBagID"] = 0,
            ["ItemSlotID"] = 0,
            ["ItemUniqueID"] = 0,
            ["ItemCreater"] = "",
            ["FinalQuality"] = 0,
            ["timestamp"] = 111222323232323232322,}
        },
        [CRAFTING_TYPE_ENCHANTING] =
        {
            {["essenceItemID"] = 0,
            ["aspectItemID"] = 0,
            ["potencyItemID"] = 0,
            ["timestamp"] = 1234232323235667,
            ["autocraft"] = true,
            ["Requester"] = "",
        }
        },
        [CRAFTING_TYPE_ALCHEMY] =
        {
            {["SolvenItemID"] = 0,
            ["Reagents"] =
            {
                [1] = 0,
                [2] = 0,
                [3] = 0,
            },
            ["timestamp"] = 123423232323555,
            ["Requester"] = "",
            ["autocraft"] = true,
        }
        },
        [CRAFTING_TYPE_PROVISIONING] =
        {
            {["RecipeID"] = 0,
            ["timestamp"] = 111232323232323111,
            ["Requester"] = "",
            ["autocraft"] = true,}
        },
    },
}
-- Remove the examples, don't want to actualy make them :D
craftingQueue["ExampleAddon"] = nil

lib.craftingQueue = craftingQueue

local craftResultFunctions = {[""]=function() end}

lib.functionTable = lib.functionTable or {}
lib.craftResultFunctions = craftResultFunctions


--------------------------------------
--- GENERAL HELPER FUNCTIONS

function GetItemNameFromItemId(itemId) -- Global due to the large general use.

    return GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 1, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0))
end

-- Mostly a queue function, but kind of a helper function too
local function isItemCraftable(request, station)

    if lib.craftInteractionTables[station].isItemCraftable then

        return lib.craftInteractionTables[station]:isItemCraftable(station, request)
    end

    if station ==CRAFTING_TYPE_ENCHANTING or station == CRAFTING_TYPE_PROVISIONING or station == CRAFTING_TYPE_ALCHEMY then
        return true
    end

end

function findItemLocationById(itemID)
    for i=0, GetBagSize(BAG_BANK) do
        if GetItemId(BAG_BANK,i)==itemID  then
            return BAG_BANK, i
        end
    end
    for i=0, GetBagSize(BAG_SUBSCRIBER_BANK) do
        if GetItemId(BAG_SUBSCRIBER_BANK,i)==itemID  then
            return BAG_SUBSCRIBER_BANK, i
        end
    end
    for i=0, GetBagSize(BAG_BACKPACK) do
        if GetItemId(BAG_BACKPACK,i)==itemID then
            return BAG_BACKPACK,i
        end
    end

    if GetItemId(BAG_VIRTUAL, itemID) ~=0 then

        return BAG_VIRTUAL, itemID

    end
    return nil, itemID
end


lib.functionTable.findItemLocationById = findItemLocationById

-- Return current backpack inventory.
function lib.backpackInventory()
    local inventory = {}
    local bagId = BAG_BACKPACK
    local maxSlotId = GetBagSize(bagId)
    local total = 0 -- to help with debugging: did ANYTHING grow?
    for slotIndex = 0, maxSlotId do
        inventory[slotIndex] = GetSlotStackSize(bagId, slotIndex)
        total = total + inventory[slotIndex]
    end
    return inventory
end

-- Return the first slot index of a stack of items that grew.
-- Return nil if no stacks grew.
--
-- prevSlotsContaining and newSlotsContaining are expected to be
-- results from backpackInventory().
function lib.findIncreasedSlotIndex(prevInventory, currInventory)
    local maxSlotId = math.max(#prevInventory, #currInventory)
    for slotIndex = 0, maxSlotId do
        local prev = prevInventory[slotIndex]
        local curr = currInventory[slotIndex]

                        -- Previously nil slot now non-nil
                        -- (can happen when #curr > #prev)
        if curr and not prev then return slotIndex end

                        -- This stack increased.
        if prev < curr then return slotIndex end
    end
    return nil
end

function lib.tableShallowCopy(t)
    local a = {}
    for k, v in pairs(t) do
        a[k] = v
    end
    return a
end
-- clear a table in-place. Allows functions to clear out tables passed as a parameter.
local function tableClear(t)
    for k,_ in ipairs(t) do
        t[k] = nil
    end
end
-- Common code called by Alchemy and Provisioning crafting complete handlers.

function lib.stackableCraftingComplete(event, station, lastCheck, craftingType, currentCraftAttempt)
    dbug("EVENT:CraftComplete")
    if not (currentCraftAttempt and currentCraftAttempt.addon) then return end
    local currSlots = lib.backpackInventory()
    local grewSlotIndex = lib.findIncreasedSlotIndex(currentCraftAttempt.prevSlots, currSlots)
    if grewSlotIndex then
        dbug("RESULT:StackableMade")
        if currentCraftAttempt["timesToMake"] < 2 then
            dbug("ACTION:RemoveQueueItem")
            table.remove( craftingQueue[currentCraftAttempt.addon][craftingType] , currentCraftAttempt.position )
            --lib.sortCraftQueue()
            local resultTable =
            {
                ["bag"] = BAG_BACKPACK,
                ["slot"] = grewSlotIndex,
                ['link'] = currentCraftAttempt.link,
                ['uniqueId'] = GetItemUniqueId(BAG_BACKPACK, currentCraftAttempt.slot),
                ["quantity"] = 1,
                ["reference"] = currentCraftAttempt.reference,
            }
            lib.SendCraftEvent( LLC_CRAFT_SUCCESS,  station, currentCraftAttempt.addon,resultTable )
            tableClear(currentCraftAttempt)
        else
            -- Loop to craft multiple copies
            local earliest = craftingQueue[currentCraftAttempt.addon][craftingType][currentCraftAttempt.position]
            earliest.timesToMake = earliest.timesToMake - 1
            currentCraftAttempt.timesToMake = earliest.timesToMake
            if GetCraftingInteractionType()==0 then zo_callLater(function() lib.stackableCraftingComplete(event, station, true, craftingType, currentCraftAttempt) end,100) end
        end
    elseif lastCheck then
        -- give up on finding it.
        tableClear(currentCraftAttempt)
    else
        -- further search
        -- search again later
        if GetCraftingInteractionType()==0 then zo_callLater(function() lib.stackableCraftingComplete(event, station, true, craftingType, currentCraftAttempt) end,100) end
    end
end

lib.newItemsSeen =
{

}

function lib:setWatchingForNewItems(state)
    self.watchForNewItems = state
    lib.newItemsSeen = {}
end

function lib.findNextSlotIndex(itemCheck, startSlot)
    if startSlot == nil then
        startSlot = -1
    end
    for k, item in pairs(lib.newItemsSeen) do
        if item.slotId>=startSlot and itemCheck(item.bagId, item.slotId) then
            table.remove(lib.newItemsSeen , k)
            return item.bagId, item.slotId
        end
    end
    return nil , nil
end

local function newItemWatcher(event, bagId, slotId, isNew, _, inventoryUpdateReason, countChange)
    dbug("New item "..GetItemLink(bagId, slotId).." at bagId "..bagId.." and slotId "..slotId)
    if lib.watchForNewItems and isNew then
        table.insert(lib.newItemsSeen, {bagId=bagId, slotId=slotId,countChange=countChange})
    end
end


EVENT_MANAGER:RegisterForEvent(lib.name.."NewItemWatcher", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, newItemWatcher)
EVENT_MANAGER:AddFilterForEvent(lib.name.."NewItemWatcher", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)

local function getItemLinkFromItemId(itemId) local name = GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 1, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0))
    return ZO_LinkHandler_CreateLink(zo_strformat("<<t:1>>",name), nil, ITEM_LINK_TYPE,itemId, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
end

function lib.HaveMaterials(materialList)
    for _, mat in ipairs(materialList) do
        local itemLink = mat.itemLink
        if (not itemLink) and mat.itemId then
            itemLink = getItemLinkFromItemId(mat.itemId)
        end
        if itemLink then
            local bagCt, bankCt, craftBagCt = GetItemLinkStacks(itemLink)
            local haveCt = bagCt + bankCt + craftBagCt
            if haveCt < mat.requiredCt then
                        -- Zig: What's the correct way to report "skipping this
                        -- request beccause you're out of Perfect Roe"?
                d("LibLazyCrafting: insufficient materials: "..tostring(itemLink)
                    ..": require "..tostring(mat.requiredCt)
                    .."  have "..tostring(haveCt))
                return false
            end
        end
    end
    return true
end

-------------------------------------
-- QUEUE FUNCTIONS

local function sortCraftQueue()
    for name, requests in pairs(craftingQueue) do
        for i = 1, 6 do
            table.sort(requests[i], function(a, b) if a and b then return a["timestamp"]<b["timestamp"] else return a end end)
        end
    end
end
lib.sortCraftQueue = sortCraftQueue


local abc = 1
-- Finds the highest priority request.
local function findEarliestRequest(station)
    local earliest = {["timestamp"] = GetTimeStamp() + 100000} -- should be later than anything else, as it's 'in the future'
    local addonName = nil
    local position = 0
    for addon, requestTable in pairs(craftingQueue) do

        for i = 1, #requestTable[station] do
            if isItemCraftable(requestTable[station][i],station)  and (requestTable[station][i]["autocraft"] or requestTable[station][i]["craftNow"]) then

                if requestTable[station][i]["timestamp"] < earliest["timestamp"] then

                    earliest = requestTable[station][i]
                    addonName = addon
                    position = i
                    break
                else
                    break
                end
            end

        end

    end
    if addonName then

        return earliest, addonName , position
    else
        return nil, nil , 0
    end
end

lib.findEarliestRequest = findEarliestRequest

local function LLC_CraftAllItems(self)
    if GetCraftingInteractionType() == 0 then return end
    for i = 1, #craftingQueue[self.addonName] do
        for j = 1, #craftingQueue[self.addonName][i] do
            craftingQueue[self.addonName][i][j]["craftNow"] = true
        end
    end
end

local function LLC_CraftItem(self, station, position)
    if GetCraftingInteractionType() == 0 then return end
    if position == nil then
        for i = 1, #craftingQueue[self.addonName][station] do
            craftingQueue[self.addonName][station][i]["craftNow"] = true
        end
    else
        craftingQueue[self.addonName][station][position]["craftNow"] = true
    end
end

local function LLC_StopCraftAllItems(self)
    if not self then
        for addonName, craftTable in pairs(craftingQueue) do
            for i = 1, #craftingQueue[addonName] do
                for j = 1, #craftingQueue[addonName][i] do
                    craftingQueue[addonName][i][j]["craftNow"] = false
                end
            end
        end
    else
        for i = 1, #craftingQueue[self.addonName] do
            for j = 1, #craftingQueue[self.addonName][i] do
                craftingQueue[self.addonName][i][j]["craftNow"] = false
            end
        end
    end
end

local function LLC_CancelItem(self, station, position)
    if position == nil then
        if station == nil then
            craftingQueue[self.addonName] = {{},{},{},{},{},{},{}}
        else
            craftingQueue[self.addonName][station] = {}
        end
    else
        table.remove(craftingQueue[self.addonName][station], position)
    end
end

local function LLC_CancelItemByReference(self, reference)
    for i = 1, #craftingQueue[self.addonName] do
        for j = 1, #craftingQueue[self.addonName][i] do
            if craftingQueue[self.addonName][i][j] and craftingQueue[self.addonName][i][j].reference==reference then

                table.remove(craftingQueue[self.addonName][i], j)

            end
        end
    end

end

local function LLC_FindItemByReference(self, reference)
    local matches = {}
    for i = 1, #craftingQueue[self.addonName] do
        for j = 1, #craftingQueue[self.addonName][i] do
            if craftingQueue[self.addonName][i][j].reference==reference then
                matches[#matches+1] = craftingQueue[self.addonName][i][j]
            end
        end
    end
    return matches
end

local function LLC_SetAllAutoCraft(self, newAutoCraftSetting)
    for i = 1, #craftingQueue[self.addonName] do
        for j = 1, #craftingQueue[self.addonName][i] do
            craftingQueue[self.addonName][i][j]["autocraft"] = newAutoCraftSetting
        end
    end
end

local function LLC_SetAutoCraft(self, station, position)
    if position == nil then
        for i = 1, #craftingQueue[self.addonName][station] do
            craftingQueue[self.addonName][station][i]["autocraft"] = true
        end
    else
        craftingQueue[self.addonName][station][position]["autocraft"] = true
    end
end

lib.functionTable.SetAllAutoCraft = LLC_SetAllAutoCraft

lib.functionTable.cancelItemByReference = LLC_CancelItemByReference

lib.functionTable.cancelItem = LLC_CancelItem

lib.functionTable.craftItem = LLC_CraftItem

lib.functionTable.CraftAllItems = LLC_CraftAllItems
lib.functionTable.findItemByReference =  LLC_FindItemByReference


local function LLC_GetMatRequirements(self, requestTable)

    if requestTable.station then
        return lib.craftInteractionTables[requestTable.station]:materialRequirements( requestTable)
    end
    if requestTable.dualEnchantingSmithing then
        return lib.craftInteractionTables[CRAFTING_TYPE_ENCHANTING]:materialRequirements( requestTable)
    end
end

lib.functionTable.getMatRequirements =  LLC_GetMatRequirements


function lib.SendCraftEvent( event,  station, requester, returnTable )
    -- First, set the item to have the new status
    -- if event==LLC_CRAFT_SUCCESS and returnTable then
    --  -- PLAYER_INVENTORY:AddInventoryItem(INVENTORY_BACKPACK, returnTable["slot"])
    --  -- PLAYER_INVENTORY:RefreshAllInventorySlots()
    --  --RefreshInventorySlot(inventoryType, slotIndex, bagId)
    --  local v = SHARED_INVENTORY:GenerateSingleSlotData(returnTable['bag'], returnTable['slot'])
    --  if v then
    --      v.brandNew = true
    --      v.age = 1
    --      SHARED_INVENTORY:RefreshStatusSortOrder(v)
    --  end
    -- end
    if event == LLC_NO_FURTHER_CRAFT_POSSIBLE then
        for requester, callbackFunction in pairs(lib.craftResultFunctions) do
            if requester ~= "LLC_Global" then
                local errorFound, err =  pcall(function() callbackFunction(event, station )end)
                if not errorFound then
                    d("Callback to LLC resulted in an error. Please contact the author of "..requester)
                    d(err)
                end
            end
        end
    else
        -- if requester == nil then return end
        local errorFound, err =  pcall(function()lib.craftResultFunctions[requester](event, station,
            returnTable )end)
        if not errorFound then
            d("Callback to LLC resulted in an error. Please contact the author of "..requester)
            d(err)
        end

    end
end



function lib:Init()
    lib.addonInteractionTables = {}
    -- Call this to register the addon with the library.
    -- Really this is mostly arbitrary, I just want to force an addon to give me their name ;p. But it's an easy way, and only needs to be done once.
    -- Returns a table with all the functions, as well as the addon's personal queue.
    -- nilable:boolean autocraft will cause the library to automatically craft anything in the queue when at a crafting station.
    -- If optionalDebugAuthor is set, then when the @name == GetDisplayName(), the library will throw errors when some invalid arguments are entered for functions
    -- Example: If an invalid level is entered for a piece of equipment, will throw and error "LLC: Invalid level"
    function lib:AddRequestingAddon(addonName, autocraft, functionCallback, optionalDebugAuthor, styleTable)
        -- Add the 'open functions' here.
        local LLCAddonInteractionTable = {}
        if lib.addonInteractionTables[addonName] then
            d("lib:AddRequestingAddon has been called twice, or the chosen addon name has already been used. Use GetRequestingAddon instead")
        end
        craftingQueue[addonName] = { {}, {}, {}, {}, {}, {}, {}} -- Initialize the addon's personal queue. The tables are empty, station specific queues.

        -- Ensures that any request will have an addon name attached to it, if needed.
        LLCAddonInteractionTable["addonName"] = addonName
        -- The crafting queue is added. Consider hiding this.

        LLCAddonInteractionTable["personalQueue"]  = craftingQueue[addonName]
        LLCAddonInteractionTable["styleTable"] = styleTable

        LLC_SHORT.debugDisplayNames[addonName] = optionalDebugAuthor

        -- Add all the functions to the interaction table!!
        -- On the other hand, then addon devs can mess up the functions?

        for functionName, functionBody in pairs(lib.functionTable) do
            LLCAddonInteractionTable[functionName] = functionBody
        end

        craftResultFunctions[addonName] = functionCallback

        LLCAddonInteractionTable.autocraft = autocraft

        -- Give add-on authors a way to check for required version beyond
        -- "I hope LibStub returns what I asked for!"
        LLCAddonInteractionTable["version"] = libVersion

        lib.addonInteractionTables[addonName] =  LLCAddonInteractionTable

        return LLCAddonInteractionTable
    end

    function  lib:GetRequestingAddon(addonName)
        return lib.addonInteractionTables[addonName]
    end


    -- Response codes
    LLC_CRAFT_SUCCESS = "success" -- extra result: Position of item, item link, maybe other stuff?
    LLC_ITEM_TO_IMPROVE_NOT_FOUND = "item not found" -- extra result: Improvement request table
    LLC_INSUFFICIENT_MATERIALS = "not enough mats" -- extra result: what is missing, item identifier
    LLC_INSUFFICIENT_SKILL  = "not enough skill" -- extra result: what skills are missing; both if not enough traits, not enough styles, or trait unknown
    LLC_NO_FURTHER_CRAFT_POSSIBLE = "no further craft items possible" -- Thrown when there is no more items that can be made at the station
    LLC_INITIAL_CRAFT_SUCCESS = "initial stage of crafting complete" -- Thrown when the white item of a higher quality item is created
    LLC_ENCHANTMENT_FAILED = "enchantment failed"
    LLC_CRAFT_PARTIAL_IMPROVEMENT = "item has been improved one stage, but is not yet at final quality"

    LLC_Global = lib:AddRequestingAddon("LLC_Global",true, function(event, station, result)
        d(GetItemLink(result.bag,result.slot).." crafted at slot "..tostring(result.slot).." with reference "..result.reference) end)

    --craftingQueue["ExampleAddon"] = nil
end

-- Allows addons to see if the library is currently crafting anything, a quick overview of what it is making, and what addon is asking for it
function lib:IsPerformingCraftProcess()
    if not lib.isCurrentlyCrafting then
        return nil
    end
    return unpack(lib.isCurrentlyCrafting)
end

function lib:SetItemStatusNew(itemSlot)
    -- d(itemSlot)
    -- PLAYER_INVENTORY:RefreshInventorySlot(1, itemSlot, BAG_BACKPACK)
    local v = PLAYER_INVENTORY:GetBackpackItem(itemSlot)

    if v then
        v.brandNew = true
        v.age = 1
        v.statusSortOrder = 1
    end
end

-- The first parameter is basically an overloaded parameter
-- If it is a table: Grabs the addonName from the table, if addonName doesn't exist, exit
--          if it does exist, and the user's name is the optional debug name for the addon, throw an error
-- If it is a string, simply check to see if the user's name is the optional debug name for the addon, throw an error
-- if it is true, always throw the error.

local function LLCThrowError(addonNameOrTableOrAlwaysThrow, message)
    local addonName
    if type(addonNameOrTable)=="table" then
        addonName = addonNameOrTable.addonName
        if not addonName then
            return
        end
    else
        addonName = addonNameOrTable
    end
    if addonName==true or LLC_SHORT.debugDisplayNames[addonName] == GetDisplayName() then
        error("LibLazyCrafting Error: Caused by "..addonName.." ; Reason: "..message.." ; Stack Trace: ")
    end
end

LLC_SHORT.LLCThrowError = LLCThrowError

------------------------------------------------------
-- CRAFT EVENT HANDLERS

-- Called when a crafting station is opened. Should then craft anything needed in the queue
local function CraftInteract(event, station)
    for k,v in pairs(lib.craftInteractionTables) do
        if v:check( station) then
            local earliest, addon , position = lib.findEarliestRequest(station)
            if earliest then
                if earliest.isFurniture then
                    if v.canCraftFurniture then
                        v["function"]( station, earliest, addon , position)
                        return
                    end
                else
                    v["function"]( station, earliest, addon , position)
                    return
                end
            end
        end
    end
    lib.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE ,  station,addon , nil )
end

lib.craftInteract = CraftInteract

local function endInteraction(event, station)
    for k,v in pairs(lib.craftInteractionTables) do
        if v:check(station) then
            v["endInteraction"](station)
        end
    end
    LLC_StopCraftAllItems()
    lib:setWatchingForNewItems(false)
end

-- Called when a crafting request is done.
-- Note that this function is called both when you finish crafting and when you leave the station
-- Additionally, the craft complete event is called BEFORE the end crafting station interaction event
-- So this function will check if the interaction is still going on, and call the endinteraction function if needed
-- which bypasses the event Manager, so that it is called first.

local function CraftComplete(event, station)

    --d("Event:completion")
    local LLCResult = nil
    for k,v in pairs(lib.craftInteractionTables) do
        if v:check( station) then
            if GetCraftingInteractionType()==0 then -- This is called when the user exits the crafting station while the game is crafting

                endInteraction(EVENT_END_CRAFTING_STATION_INTERACT, station)
                zo_callLater(function() v["complete"]( station) lib.isCurrentlyCrafting = {false, "", ""} end, timetest)
                return
            else
                v["complete"]( station)
                lib.isCurrentlyCrafting = {false, "", ""}
                local earliest, addon , position = lib.findEarliestRequest(station)
                if earliest then
                    if earliest.isFurniture then
                        if v.canCraftFurniture then
                            v["function"]( station, earliest, addon , position)
                            return
                        end
                    else
                        v["function"]( station, earliest, addon , position)
                        return
                    end
                end
            end
        end
    end
    lib.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE ,  station,addon , nil )
end


lib.functionTable.craftInteract =function()
if GetCraftingInteractionType() ~= 0 then
    CraftInteract(nil, GetCraftingInteractionType())
end
end

local function OnAddonLoaded()
    if not libLoaded then
        libLoaded = true
        lib:Init()
        EVENT_MANAGER:UnregisterForEvent(libName, EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(libName, EVENT_CRAFTING_STATION_INTERACT,CraftInteract)
        EVENT_MANAGER:RegisterForEvent(libName, EVENT_CRAFT_COMPLETED, CraftComplete)
        EVENT_MANAGER:RegisterForEvent(libName, EVENT_END_CRAFTING_STATION_INTERACT, endInteraction)

    end
end

EVENT_MANAGER:RegisterForEvent(libName, EVENT_ADD_ON_LOADED, OnAddonLoaded)

LibLazyCrafting = lib
