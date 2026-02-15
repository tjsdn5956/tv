Config = {}

Config.Models = { -- Any TV Models used on the map or in locations must be defined here.
    -- [`des_tvsmash_start`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_flatscreen_overlay`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_laptop_lester2`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_monitor_02`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_trev_tv_01`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_02`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_03_overlay`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_06`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_01`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_01_screen`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_02b`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_03`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_03b`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_flat_michael`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_monitor_w_large`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    -- [`prop_tv_03`] = {
    --     DefaultVolume = 0.5,
    --     Range = 20.0,
    --     Target = "tvscreen", -- Only use if prop has render-target name.
    --     Scale = 0.085, 
    --     Offset = vector3(-1.02, -0.055, 1.04)
    -- },
    [`elysium_ilev_cin_screen`] = {
        DefaultVolume = 0.5,
        Range = 80.0,
        Target = "cinscreen", -- Only use if prop has render-target name.
        Scale = 0.085, 
        Offset = vector3(-1.02, -0.055, 1.04)
    },
}

Config.Locations = { -- REMOVE ALL IF NOT USING ONESYNC, OR IT SHALL BREAK.
    {
        Model = `elysium_ilev_cin_screen`,
        Position = vector4(195.46453857422,-890.66772460938,29.539775848389, 326.5),
    },
}

Config.Channels = { -- These channels are default channels and cannot be overriden.
    {name = "Twitch", url = "twitch.tv/twitch"},
}

Config.BannedWords = {
    "google",
}

Config.Events = { -- Events for approving broadcasts / interactions (due to popular demand).
    ScreenInteract = function(source, data, key, value, cb) -- cb() to approve. 
        if value.url then 
            for i=1, #Config.BannedWords do 
                if string.find(value.url, Config.BannedWords[i]) then 
                    return
                end
            end
        end
        cb()
    end,    
    Broadcast = function(source, data, cb)  -- cb() to approve. 
        cb()
    end,
}
