local usedPeds = {}

local function notify(msg, ntype)
    if GetResourceState("ox_lib") == "started" then
        exports.ox_lib:notify({
            description = msg,
            type = ntype or "info",
        })
        return
    end

    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function tryLoadAnimDict(dict, timeoutMs)
    RequestAnimDict(dict)
    local start = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - start >= timeoutMs then
            return false
        end
        Wait(10)
    end
    return true
end

local function debugLog(msg)
    if Config.Debug then
        print(("[pickpokets] %s"):format(msg))
    end
end

local function checkCooldownBeforeStart()
    if GetResourceState("ox_lib") == "started" and lib and lib.callback and lib.callback.await then
        local ok, allowed, remaining = pcall(function()
            return lib.callback.await("pickpokets:server:canStart", false)
        end)

        if ok and allowed == false then
            local remainingSeconds = (remaining and remaining > 0) and remaining or 0
            debugLog(("cooldown remaining: %ds"):format(remainingSeconds))
            notify(("Cooldown: %ds remaining."):format(remainingSeconds), "warning")
            return false
        end
    end
    return true
end

local function canStartPickpocket()
    return checkCooldownBeforeStart()
end

local function findClosestPed(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed = nil
    local closestDist = maxDistance + 0.01

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
    debugLog("doPickpocket called")
    debugLog(("player ped: %s | target ped: %s"):format(tostring(PlayerPedId()), tostring(ped)))
    if usedPeds[ped] then
        notify("This person already looks wary.")
        return
    end

    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, true) then
        notify("Get out of the vehicle first.")
        return
    end
    if not DoesEntityExist(ped) then
        debugLog("target ped does not exist")
        return
    end
    if IsPedDeadOrDying(ped, true) then
        debugLog("target ped dead or dying")
        return
    end
    local maxDist = Config.PickpocketDistance or Config.OxTargetDistance
    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(ped))
    debugLog(("pickpocket distance check: %.2f (max %.2f)"):format(dist, maxDist))
    if dist > maxDist then
        notify("Get closer first.")
        return
    end
    if not checkCooldownBeforeStart() then
        debugLog("cooldown blocked start")
        return
    end

    usedPeds[ped] = true
    debugLog("marked ped as used")

    TaskTurnPedToFaceEntity(playerPed, ped, 500)
    TaskTurnPedToFaceEntity(ped, playerPed, 500)
    Wait(500)

    local animDict = Config.AnimDict
    local animClip = Config.AnimClip
    local completed = false
    local usedOx = false
    local animOk = animDict and animClip and tryLoadAnimDict(animDict, 800) or false
    debugLog(("anim dict '%s' load ok: %s"):format(tostring(animDict), tostring(animOk)))

    if GetResourceState("ox_lib") == "started" then
        debugLog("ox_lib started, trying progressBar export")
        local ok, result = pcall(function()
            return exports.ox_lib:progressBar({
                duration = Config.DurationMs,
                label = "Robbing...",
                useWhileDead = false,
                canCancel = false,
                disable = { car = false, combat = true },
                anim = animOk and { dict = animDict, clip = animClip } or nil,
            })
        end)

        if ok then
            debugLog(("ox_lib progressBar result: %s"):format(tostring(result)))
            usedOx = true
            completed = (result == true)
        else
            debugLog(("ox_lib progressBar failed: %s"):format(tostring(result)))
        end
    else
        debugLog("ox_lib not started, using fallback")
    end

    if not usedOx then
        if animOk then
            TaskPlayAnim(playerPed, animDict, animClip, 2.0, 2.0, Config.DurationMs, 1, 0, false, false, false)
            debugLog("fallback animation started")
        else
            debugLog("fallback animation skipped (anim dict not loaded)")
        end
        Wait(Config.DurationMs)
        completed = true
    end

    ClearPedTasks(playerPed)

    if not completed then
        debugLog("progress cancelled or failed")
        usedPeds[ped] = nil
        notify("You stopped pickpocketing.")
        return
    end

    local finishPlayerCoords = GetEntityCoords(playerPed)
    local finishTargetCoords = GetEntityCoords(ped)
    local finishDist = #(finishPlayerCoords - finishTargetCoords)
    local finishMax = Config.RewardDistance or Config.PickpocketDistance or Config.OxTargetDistance
    debugLog(("finish distance: %.2f (max %.2f)"):format(finishDist, finishMax))
    if finishDist > finishMax then
        debugLog("finish distance exceeded, cancelling outcome")
        usedPeds[ped] = nil
        notify("You moved too far away.")
        return
    end

    local fail = (math.random() < Config.FailChance)
    debugLog(("roll fail: %s (chance %.2f)"):format(tostring(fail), Config.FailChance))
    if fail then
        local weapons = Config.FailWeapons or {}
        local weaponName = weapons[math.random(1, #weapons)] or "WEAPON_PISTOL"
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

        TriggerServerEvent("pickpokets:server:fail")
        notify("You got caught!")
    else
        local rewardDist = #(finishPlayerCoords - finishTargetCoords)
        local rewardMax = Config.RewardDistance or Config.PickpocketDistance or Config.OxTargetDistance
        debugLog(("reward distance: %.2f (max %.2f)"):format(rewardDist, rewardMax))
        if rewardDist > rewardMax then
            notify("Too far from the target to grab the loot.")
            return
        end
        TriggerServerEvent("pickpokets:server:reward")
    end
end

local function registerOxTarget()
    if not Config.UseOxTarget then
        return
    end
    if GetResourceState("ox_target") ~= "started" then
        return
    end

    exports.ox_target:addGlobalPed({
        {
            name = "pickpokets:pickpocket",
            icon = "fa-solid fa-hand",
            label = "Pickpocket",
            distance = Config.OxTargetDistance,
            canInteract = function(entity, distance)
                if distance > Config.OxTargetDistance then
                    return false
                end
                if Config.PickpocketDistance and distance > Config.PickpocketDistance then
                    return false
                end
                if not DoesEntityExist(entity) or IsPedAPlayer(entity) then
                    return false
                end
                if IsPedDeadOrDying(entity, true) or IsPedInAnyVehicle(entity, true) then
                    return false
                end
                if usedPeds[entity] then
                    return false
                end
                return true
            end,
            onSelect = function(data)
                if data and data.entity then
                    if not canStartPickpocket() then
                        debugLog("cooldown blocked start (onSelect)")
                        return
                    end
                    doPickpocket(data.entity)
                end
            end,
        },
    })
end

CreateThread(function()
    registerOxTarget()
end)

RegisterNetEvent("pickpokets:client:notify", function(msg)
    notify(msg)
end)
