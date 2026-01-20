local framework = Config.Framework
local ESX = nil
local QBCore = nil
local cooldowns = {}

local function initFramework()
    if framework == "none" then return end
    if (framework == "auto" or framework == "esx") and GetResourceState("es_extended") == "started" then
        if exports and exports["es_extended"] and exports["es_extended"].getSharedObject then
            ESX = exports["es_extended"]:getSharedObject()
        else
            TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
        end
        if ESX then framework = "esx"; return end
    end
    if (framework == "auto" or framework == "qb") and GetResourceState("qb-core") == "started" then
        QBCore = exports["qb-core"]:GetCoreObject()
        if QBCore then framework = "qb"; return end
    end
    framework = "none"
end

initFramework()

local function debugLog(msg)
    if Config and Config.Debug then
        print(("[pickpokets:server] %s"):format(tostring(msg)))
    end
end

debugLog(("framework set to %s"):format(tostring(framework)))

local function notify(src, msg, ntype)
    if GetResourceState("ox_lib") == "started" then
        TriggerClientEvent("ox_lib:notify", src, { description = msg, type = ntype or "info" })
        return
    end
    TriggerClientEvent("pickpokets:client:notify", src, msg)
end

local function getCooldownRemaining(src)
    local last = cooldowns[src] or 0
    local now = os.time()
    local remaining = (Config.CooldownSeconds or 0) - (now - last)
    if remaining < 0 then remaining = 0 end
    debugLog(("getCooldownRemaining(%s) -> %d"):format(tostring(src), remaining))
    return remaining
end

local callbacksRegistered = false
local function registerCallbacks()
    if callbacksRegistered then return end
    if lib and lib.callback then
        lib.callback.register("pickpokets:server:canStart", function(src)
            local remaining = getCooldownRemaining(src)
            if remaining > 0 then return false, remaining end
            return true, 0
        end)
        callbacksRegistered = true
        debugLog("lib callbacks registered")
    end
end

CreateThread(function()
    while not callbacksRegistered do
        if GetResourceState("ox_lib") == "started" then registerCallbacks() end
        Wait(500)
    end
end)

local function getItemReward()
    if not Config.Items or #Config.Items == 0 then return nil, 0 end
    local entry = Config.Items[math.random(1, #Config.Items)]
    local amount = math.random(entry.min or 1, entry.max or 1)
    debugLog(("selected item reward: %s x%d"):format(tostring(entry.name), amount))
    return entry.name, amount
end

local function isItemConfigured(itemName)
    if not itemName or not Config.Items then return false end
    for _, e in ipairs(Config.Items) do
        if e and e.name == itemName then return true end
    end
    return false
end

local function giveReward(src)
    local itemName, itemAmount = getItemReward()
    debugLog(("giveReward called for src=%s -> %s x%d"):format(tostring(src), tostring(itemName), itemAmount or 0))
    if itemName and itemAmount > 0 and isItemConfigured(itemName) then
        if framework == "esx" and ESX then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addInventoryItem(itemName, itemAmount)
                notify(src, ("You stole %sx %s."):format(itemAmount, itemName))
            end
            if not xPlayer then debugLog(("ESX player not found for src=%s"):format(tostring(src))) end
            return
        end

        if framework == "qb" and QBCore then
            local player = QBCore.Functions.GetPlayer(src)
            if player then
                player.Functions.AddItem(itemName, itemAmount)
                notify(src, ("You stole %sx %s."):format(itemAmount, itemName))
            end
            if not player then debugLog(("QBCore player not found for src=%s"):format(tostring(src))) end
            return
        end

        notify(src, ("You would have received %sx %s (no framework set)."):format(itemAmount, itemName))
    else
        notify(src, "You stole nothing.")
    end
end

RegisterNetEvent("pickpokets:server:reward", function()
    local src = source
    debugLog(("pickpokets:server:reward event from %s"):format(tostring(src)))
    local remaining = getCooldownRemaining(src)
    if remaining > 0 then
        notify(src, ("Cooldown: %ds remaining."):format(remaining), "warning")
        return
    end
    cooldowns[src] = os.time()
    giveReward(src)
    if Config.DispatchOnSuccess then
        TriggerClientEvent('pickpokets:client:dispatch', src, "Pickpocketing completed")
    end
end)

RegisterNetEvent("pickpokets:server:fail", function()
    local src = source
    debugLog(("pickpokets:server:fail event from %s"):format(tostring(src)))
    if Config.DispatchOnFail then
        TriggerClientEvent('pickpokets:client:dispatch', src, "Pickpocketing in progress")
    end
end)

AddEventHandler("playerDropped", function()
    cooldowns[source] = nil
end)
