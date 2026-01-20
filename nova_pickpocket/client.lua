local usedPeds = {}

local function notify(msg, ntype)
    if GetResourceState("ox_lib") == "started" then
        exports.ox_lib:notify({ description = msg, type = ntype or "info" })
        return
    end
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

local function loadAnimDict(dict)
    if not dict then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function tryLoadAnimDict(dict, timeoutMs)
    if not dict then return false end
    RequestAnimDict(dict)
    local start = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - start >= (timeoutMs or 1000) then
            return false
        end
        Wait(10)
    end
    return true
end

local function debugLog(msg)
    if Config and Config.Debug then
        print(('[pickpokets] %s'):format(msg))
    end
end

local function checkCooldownBeforeStart()
    if GetResourceState("ox_lib") == "started" and lib and lib.callback and lib.callback.await then
        local ok, allowed, remaining = pcall(function()
            return lib.callback.await("pickpokets:server:canStart", false)
        end)
        if ok and allowed == false then
            local remainingSeconds = (remaining and remaining > 0) and remaining or 0
            debugLog(('cooldown remaining: %ds'):format(remainingSeconds))
            notify(('Cooldown: %ds remaining.'):format(remainingSeconds), "warning")
            return false
        end
    end
    return true
end

local function findClosestPed(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = (maxDistance or 3.0) + 0.01
    for _, ped in ipairs(GetGamePool("CPed")) do
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
            if not IsPedDeadOrDying(ped, true) and IsPedHuman(ped) and not IsPedInAnyVehicle(ped, true) then
                local dist = #(playerCoords - GetEntityCoords(ped))
                if dist < closestDist then
                    closestDist = dist
                    closestPed = ped
                end
            end
        end
    end
    return closestPed
end

local function doPickpocket(ped)
    debugLog('doPickpocket called')
    debugLog(('target ped: %s'):format(tostring(ped)))
    if usedPeds[ped] then
        notify('This person already looks wary.')
        return
    end
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, true) then
        notify('Get out of the vehicle first.')
        return
    end
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, true) then
        debugLog('invalid target')
        return
    end

    local maxDist = Config.PickpocketDistance or Config.OxTargetDistance or 2.0
    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(ped))
    if dist > maxDist then
        notify('Get closer first.')
        return
    end
    if not checkCooldownBeforeStart() then
        return
    end

    usedPeds[ped] = true
    debugLog(('marked ped used: %s'):format(tostring(ped)))

    TaskTurnPedToFaceEntity(playerPed, ped, 500)
    TaskTurnPedToFaceEntity(ped, playerPed, 500)
    Wait(500)

    local animDict = Config.AnimDict
    local animClip = Config.AnimClip
    local animOk = tryLoadAnimDict(animDict, 800)
    debugLog(('anim load ok: %s (%s:%s)'):format(tostring(animOk), tostring(animDict), tostring(animClip)))

    local completed = false
    if GetResourceState('ox_lib') == 'started' then
        debugLog('using ox_lib progressBar')
        local ok, result = pcall(function()
            return exports.ox_lib:progressBar({
                duration = Config.DurationMs,
                label = 'Robbing...',
                useWhileDead = false,
                canCancel = false,
                disable = { car = false, combat = true },
                anim = animOk and { dict = animDict, clip = animClip } or nil,
            })
        end)
        if ok then
            debugLog(('ox_lib result: %s'):format(tostring(result)))
            completed = (result == true)
        end
    else
        debugLog('using fallback progress')
        if animOk then
            TaskPlayAnim(playerPed, animDict, animClip, 2.0, 2.0, Config.DurationMs, 1, 0, false, false, false)
            debugLog('fallback animation started')
        end
        Wait(Config.DurationMs)
        completed = true
    end

    ClearPedTasks(playerPed)
    if not completed then
        debugLog('pickpocket not completed (cancelled)')
        usedPeds[ped] = nil
        notify('You stopped pickpocketing.')
        return
    end

    local finishPlayerCoords = GetEntityCoords(playerPed)
    local finishTargetCoords = GetEntityCoords(ped)
    local finishDist = #(finishPlayerCoords - finishTargetCoords)
    local finishMax = Config.RewardDistance or Config.PickpocketDistance or Config.OxTargetDistance
    if finishDist > finishMax then
        usedPeds[ped] = nil
        notify('You moved too far away.')
        return
    end

    local fail = (math.random() < (Config.FailChance or 0))
    debugLog(('fail roll: %s (chance %.2f)'):format(tostring(fail), Config.FailChance or 0))
    if fail then
        local weapons = Config.FailWeapons or {}
        local weaponName = weapons[math.random(1, #weapons)] or 'WEAPON_PISTOL'
        local weaponHash = joaat(weaponName)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAbility(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedCombatRange(ped, 2)
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAttributes(ped, 46, true)
        SetPedAccuracy(ped, 35)
        SetPedSeeingRange(ped, 30.0)
        SetPedHearingRange(ped, 30.0)
        SetPedDropsWeaponsWhenDead(ped, false)
        GiveWeaponToPed(ped, weaponHash, 90, false, true)
        SetCurrentPedWeapon(ped, weaponHash, true)
        SetPedAsEnemy(ped, true)
        TaskCombatPed(ped, playerPed, 0, 16)
        TriggerServerEvent('pickpokets:server:fail')
        debugLog('triggered server:fail')
        notify('You got caught!')
    else
        local rewardDist = #(finishPlayerCoords - finishTargetCoords)
        local rewardMax = Config.RewardDistance or Config.PickpocketDistance or Config.OxTargetDistance
        if rewardDist > rewardMax then
            notify('Too far from the target to grab the loot.')
            return
        end
        TriggerServerEvent('pickpokets:server:reward')
        debugLog('triggered server:reward')
    end
end

local function registerOxTarget()
    if GetResourceState('ox_target') ~= 'started' then return end
    debugLog('registering ox_target globals')
    exports.ox_target:addGlobalPed({
        {
            name = 'pickpokets:pickpocket',
            icon = 'fa-solid fa-hand',
            label = 'Pickpocket',
            distance = Config.OxTargetDistance,
            canInteract = function(entity, distance)
                if distance > (Config.OxTargetDistance or 2.0) then return false end
                if Config.PickpocketDistance and distance > Config.PickpocketDistance then return false end
                if not DoesEntityExist(entity) or IsPedAPlayer(entity) then return false end
                if IsPedDeadOrDying(entity, true) or IsPedInAnyVehicle(entity, true) then return false end
                if usedPeds[entity] then return false end
                return true
            end,
            onSelect = function(data)
                if data and data.entity then
                    if not checkCooldownBeforeStart() then return end
                    doPickpocket(data.entity)
                end
            end,
        }
    })
end

CreateThread(function()
    registerOxTarget()
end)

RegisterNetEvent('pickpokets:client:notify', function(msg)
    notify(msg)
end)

-- Dispatch bridge: construct ps-dispatch payload and send to server
RegisterNetEvent('pickpokets:client:dispatch', function(message)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local streetHash, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or "unknown"
    local zone = GetNameOfZone(coords.x, coords.y, coords.z)

    local dispatchData = {
        message = message or "Pickpocket in progress",
        codeName = 'pickpocket',
        code = '10-35',
        icon = 'fas fa-user',
        priority = 2,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        street = street .. ', ' .. zone,
        heading = GetEntityHeading(ped),
        jobs = { 'leo' }
    }

    -- Forward to ps-dispatch server event
    TriggerServerEvent('ps-dispatch:server:notify', dispatchData)
end)
