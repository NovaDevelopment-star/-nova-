local framework = Config.Framework
local ESX = nil
local QBCore = nil
local cooldowns = {}

local function initFramework()
    if framework == "none" then
        return
    end
    if framework == "auto" or framework == "esx" then
        if GetResourceState("es_extended") == "started" then
            if exports and exports["es_extended"] and exports["es_extended"].getSharedObject then
                ESX = exports["es_extended"]:getSharedObject()
            else
                TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
            end
            if ESX then
                framework = "esx"
                return
            end
        end
    end
    if framework == "auto" or framework == "qb" then
        if GetResourceState("qb-core") == "started" then
            QBCore = exports["qb-core"]:GetCoreObject()
            if QBCore then
                framework = "qb"
                return
            end
        end
    end
    framework = "none"
end

initFramework()

local function notify(src, msg, ntype)
    if GetResourceState("ox_lib") == "started" then
        TriggerClientEvent("ox_lib:notify", src, {
            description = msg,
            type = ntype or "info",
        })
        return
    end

    TriggerClientEvent("pickpokets:client:notify", src, msg)
end

local function getCooldownRemaining(src)
    local last = cooldowns[src] or 0
    local now = os.time()
    local remaining = Config.CooldownSeconds - (now - last)
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

local callbacksRegistered = false
local function registerCallbacks()
    if callbacksRegistered then
        return
    end
    if lib and lib.callback then
        lib.callback.register("pickpokets:server:canStart", function(src)
            local remaining = getCooldownRemaining(src)
            if remaining > 0 then
                return false, remaining
            end
            return true, 0
        end)
        callbacksRegistered = true
    end
end

CreateThread(function()
    while not callbacksRegistered do
        if GetResourceState("ox_lib") == "started" then
            registerCallbacks()
        end
        Wait(500)
    end
end)

local function getItemReward()
    if #Config.Items == 0 then
        return nil, 0
    end
    local entry = Config.Items[math.random(1, #Config.Items)]
    local amount = math.random(entry.min, entry.max)
    return entry.name, amount
end

local function giveReward(src)
    local cash = math.random(Config.CashReward.min, Config.CashReward.max)
    local itemName, itemAmount = getItemReward()

    if framework == "esx" and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then
            return
        end
        xPlayer.addMoney(cash)
        if itemName and itemAmount > 0 then
            xPlayer.addInventoryItem(itemName, itemAmount)
        end
        notify(src, ("You stole $%d and %sx %s."):format(cash, itemAmount, itemName or "item"))
        return
    end

    if framework == "qb" and QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then
            return
        end
        player.Functions.AddMoney("cash", cash)
        if itemName and itemAmount > 0 then
            player.Functions.AddItem(itemName, itemAmount)
        end
        notify(src, ("You stole $%d and %sx %s."):format(cash, itemAmount, itemName or "item"))
        return
    end

    notify(src, ("You would have received $%d and %sx %s (no framework set).")
        :format(cash, itemAmount, itemName or "item"))
end

RegisterNetEvent("pickpokets:server:reward", function()
    local src = source
    local remaining = getCooldownRemaining(src)
    if remaining > 0 then
        notify(src, ("Cooldown: %ds remaining."):format(remaining), "warning")
        return
    end
    cooldowns[src] = os.time()
    giveReward(src)
    if Config.DispatchOnSuccess then
        TriggerEvent(Config.DispatchEvent, src, "Pickpocketing completed")
    end
end)

RegisterNetEvent("pickpokets:server:fail", function()
    local src = source
    if Config.DispatchOnFail then
        TriggerEvent(Config.DispatchEvent, src, "Pickpocketing in progress")
    end
end)

AddEventHandler("playerDropped", function()
    cooldowns[source] = nil
end)
