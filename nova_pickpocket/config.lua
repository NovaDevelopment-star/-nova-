-- Pickpocket configuration (clean template)
Config = {}

-- Debug logging
Config.Debug = true

-- Framework detection: "auto", "esx", "qb", or "none"
Config.Framework = "auto"

-- ox_target integration
Config.OxTargetDistance = 2.0
Config.RewardDistance = 1.8

-- Timing and behavior
Config.DurationMs = 3000        -- progress duration in ms
Config.CooldownSeconds = 90     -- per-player cooldown after a successful attempt
Config.FailChance = 0.1          -- chance (0.0-1.0) to fail and trigger combat

-- Item rewards (only items listed here will be given)
-- Example: { name = "phone", min = 1, max = 1 }
Config.Items = {
    { name = "cash", min = 20, max = 100 },
    { name = "bread", min = 1, max = 3 },
    { name = "water", min = 1, max = 2 },
}

-- Weapons NPCs can use when you fail a pickpocket
Config.FailWeapons = { "WEAPON_STUNGUN", "WEAPON_PISTOL" }

-- Dispatch: server triggers a client dispatch event; client forwards to `ps-dispatch`.
Config.DispatchOnFail = true
Config.DispatchOnSuccess = true


-- Progress animation
Config.AnimDict = "missexile3"
Config.AnimClip = "ex03_dingy_search_case_a_michael"
