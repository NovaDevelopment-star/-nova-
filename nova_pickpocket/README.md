# pickpokets

Pickpocket local NPCs for random items and cash.

## Install
- Drop `pickpokets` into your `resources` folder.
- Add `ensure pickpokets` to your `server.cfg`.

## Use
- Use ox_target on a nearby NPC.
- Edit `config.lua` to adjust rewards, cooldowns, and framework.

## Notes
- Supports ESX or QBCore when `Config.Framework = "auto"`.
- With no framework, rewards are only shown as a notification.
- Requires `ox_target` for targeting
- Enable `Config.DispatchOnFail` or `Config.DispatchOnSuccess` to notify police.
- If you are using ps-dispatch then paste the below codein client/alert.lua

     <!-- ['PickpocketingInProgress'] = { -- Need to match the codeName in alerts.lua
        radius = 0,
        sprite = 119,
        color = 1,
        scale = 1.5,
        length = 2,
        sound = 'Lose_1st',
        sound2 = 'GTAO_FM_Events_Soundset',
        offset = false,
        flash = false
    }, -->


- If you are using ps-dispatch then paste the below codein shared/config.lua

```
local function PickpocketingInProgress()
    local coords = GetEntityCoords(cache.ped)
    local vehicle = GetVehicleData(cache.vehicle)

    local dispatchData = {
        message = locale('Pickpocketing in progress'), -- add this into your locale
        codeName = 'Pickpocketing in progress', -- this should be the same as in config.lua
        code = '10-35',
        icon = 'fas fa-car-burst',
        priority = 2,
        coords = coords,
        street = GetStreetAndZone(coords),
        heading = GetPlayerHeading(),
        jobs = { 'leo' }
    }

    TriggerServerEvent('ps-dispatch:server:notify', dispatchData)
end
exports('PickpocketingInProgress', PickpocketingInProgress)
```