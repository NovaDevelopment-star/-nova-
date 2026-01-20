Config = {}

-- "auto", "esx", "qb", or "none"
Config.Framework = "auto"

-- Command/key mapping
-- ox_target integration
Config.UseOxTarget = true
Config.OxTargetDistance = 2.0
Config.RewardDistance = 1.80 

Config.DurationMs = 3000
Config.CooldownSeconds = 90
Config.FailChance = 0

Config.CashReward = { min = 25, max = 150 }

Config.Items = {
    { name = "phone", min = 1, max = 1 },
    -- { name = "", min = 1, max = 1 },
    -- { name = "", min = 1, max = 3 },
}

-- Weapons NPCs can use when you fail a pickpocket
Config.FailWeapons = { "WEAPON_STUNGUN", "WEAPON_PISTOL" }

-- Optional dispatch hook when you fail
Config.DispatchOnFail = true
Config.DispatchEvent = "police:server:policeAlert"
Config.DispatchOnSuccess = true



-- Debug logging
Config.Debug = true

-- Progress animation
Config.AnimDict = "missexile3"
Config.AnimClip = "ex03_dingy_search_case_a_michael"
