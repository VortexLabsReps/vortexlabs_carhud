--[[
    vortexlabs_carhud · VortexLabs Car HUD
    Server configuration. Everything here is a server limit: player settings
    (the /carhud menu) can never go beyond it.

    Speeds are in km/h and times in ms unless stated otherwise.
]]

Config = {}

-- Language for the interface, key descriptions and messages: any file in
-- locales/ ('en', 'es'). Missing texts fall back to English.
Config.Locale = 'en'

-- Framework: 'auto' | 'standalone' | 'esx' | 'qbcore' | 'qbox'
-- 'auto' checks in this order: qbx_core → qb-core → es_extended → standalone.
-- No framework is required: the HUD and all its features work standalone.
Config.Framework = 'auto'

-- Diagnostic messages in the F8 / server console.
Config.Debug = false

------------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------------
Config.Hud = {
    accent = '#FE3555',          -- initial accent colour, VortexLabs coral (players can change it if allowColor)
    defaultUnit = 'kmh',         -- 'kmh' | 'mph'
    showForPassengers = true,    -- passengers see the HUD (without the driver's controls)
    requirePlayerLoaded = true,  -- with a framework: hidden until the character has loaded
    hideWhenHudHidden = true,    -- hide when another resource hides the native HUD (DisplayHud false)
    hideWhenRadarHidden = false, -- hide the whole HUD when the minimap is hidden
    -- Native components that overlap the HUD (vehicle name, area, class and
    -- street); hidden while the HUD is visible.
    hideNativeComponents = { 6, 7, 8, 9 },
    -- Notices for the resource's own features: 'hud' (above the HUD) | 'framework'
    notify = 'hud',
}

-- Read rates (ms). The interface interpolates between readings.
Config.Rates = {
    fast = 50,     -- speed, RPM, gear, throttle, altitude
    slow = 250,    -- fuel, engine, lights, seatbelt, nitro, notices
    idle = 500,    -- outside a vehicle: only checks whether the player gets in
}

------------------------------------------------------------------------------
-- Own features (global switch). Disabling one here removes the feature and its
-- key for the whole server, whatever the vehicle category.
------------------------------------------------------------------------------
Config.Features = {
    seatbelt   = true,
    lights     = true,  -- own low/high beam control
    indicators = true,  -- own indicators and hazard lights
    cruise     = true,
    engine     = true,  -- own engine start/stop
    nitro      = true,
}

------------------------------------------------------------------------------
-- Category matrix: what is shown and what works for each vehicle type.
-- maxSpeed: arc scale in km/h (number) or 'auto' (estimated top speed of the
-- model × 1.15, rounded to 20 and limited between autoMin and autoMax).
-- redline: cut-off RPM used to convert the game's normalised RPM (0–1).
------------------------------------------------------------------------------
Config.Categories = {
    car = {
        hud = true,
        gear = true, rpm = true, throttle = true, fuel = true, engine = true,
        nitro = true,
        seatbelt = true, lights = true, indicators = true, cruise = true, engineToggle = true,
        maxSpeed = 'auto', autoMin = 160, autoMax = 360, fallbackMax = 260,
        redline = 8000,
    },
    motorcycle = {
        hud = true, compact = true,
        gear = true, rpm = true, throttle = true, fuel = true, engine = true,
        nitro = true,                     -- only once nitro is actually installed
        seatbelt = false, lights = true, indicators = true, cruise = true, engineToggle = true,
        maxSpeed = 'auto', autoMin = 160, autoMax = 340, fallbackMax = 240,
        redline = 11000,
    },
    boat = {
        hud = true,
        gear = false, rpm = true, throttle = true, fuel = true, engine = true,
        nitro = false,
        seatbelt = false, lights = true, indicators = false, cruise = false, engineToggle = true,
        maxSpeed = 'auto', autoMin = 80, autoMax = 200, fallbackMax = 120,
        redline = 6000,
    },
    plane = {
        hud = true, aircraft = 'plane',
        gear = false, rpm = false, throttle = true, fuel = true, engine = true,
        nitro = false,
        seatbelt = false, lights = false, indicators = false, cruise = false, engineToggle = true,
        altitudeMsl = true, altitudeAgl = true,
        maxSpeed = 'auto', autoMin = 300, autoMax = 800, fallbackMax = 500,
    },
    heli = {
        hud = true, aircraft = 'heli',
        gear = false, rpm = false, throttle = true, fuel = true, engine = true,
        nitro = false,
        seatbelt = false, lights = false, indicators = false, cruise = false, engineToggle = true,
        altitudeAgl = true, verticalSpeed = true,
        maxSpeed = 'auto', autoMin = 200, autoMax = 400, fallbackMax = 300,
    },
    -- Bicycles: the HUD never appears and no feature is active.
    bicycle = { hud = false },
    -- Trains: no HUD by default.
    train = { hud = false },
}

-- Per-model overrides (spawn name). Any category key can be overridden;
-- 'category' moves the model to another category entirely.
Config.Models = {
    -- ['mybike']     = { category = 'bicycle' },          -- custom bicycle with the wrong class
    -- ['ebike']      = { category = 'motorcycle', seatbelt = false },
    -- ['sultanrs']   = { maxSpeed = 300, redline = 9000 },
    -- ['polmav']     = { hud = false },
}

------------------------------------------------------------------------------
-- Location above the minimap (street, area and heading). Each player can hide,
-- move and scale it in /carhud; it can be disabled for everyone here.
------------------------------------------------------------------------------
Config.Location = {
    enabled = true,
    placeRate = 500,   -- ms between street/area readings (only sent when they change)
    headingRate = 150, -- ms between heading readings
    hysteresis = 8,    -- degrees of margin before switching to the next compass point
    gap = 12,          -- px (at 1080p) between the location bar and the top edge of the minimap
    -- Default position and size (also used by "Reset position" and "Reset size").
    -- x/y: offset from the anchor (minimap edges plus gap) as a fraction of the
    -- screen height; 20 / 1080 = 20 px at 1080p. Use /carhud layout to print a
    -- position you have placed in game and copy it here.
    default = { x = 20 / 1080, y = -37 / 1080, scale = 1.02 },
    -- Minimap measurements ('minimap' component of frontend.xml, L/B aligned).
    -- Only change them if your server moves the minimap with SetMinimapComponentPosition.
    minimap = { posX = -0.0045, posY = 0.002, sizeX = 0.150, sizeY = 0.188888 },
}

------------------------------------------------------------------------------
-- Seatbelt
------------------------------------------------------------------------------
Config.Seatbelt = {
    -- 'auto'     → 'external' if a known seatbelt resource is running (qbx_seatbelt), otherwise 'own'
    -- 'own'      → built-in mechanic (key, sounds, warning, exit lock, ejection)
    -- 'external' → only shows the state of another resource (statebag / event)
    -- 'off'      → no seatbelt
    mode = 'auto',
    knownResources = { 'qbx_seatbelt' },
    external = {
        stateKey = 'seatbelt',                       -- LocalPlayer.state.<stateKey>
        harnessKey = 'harness',                      -- harness: counts as buckled
        toggleEvent = 'seatbelt:client:ToggleSeatbelt', -- fallback when there is no statebag
    },
    key = 'B',
    lockExit = true,           -- block exiting while buckled (exit key only; never forced exits)
    warnSound = true,          -- warning sound while driving unbuckled
    warnSpeed = 20,            -- km/h from which the unbuckled warning plays
    warnInterval = 7000,       -- ms between warning sounds while the condition lasts
    ejection = {
        enabled = true,
        -- THRESHOLD (when an ejection happens). The VELOCITY VECTOR is measured:
        -- frontal, rear, side and diagonal crashes, reversing into obstacles and
        -- hits from other vehicles. Collision evidence is required; jumps,
        -- landings and teleports are discarded. /carhudcrash shows each decision.
        minSpeed = 75,         -- km/h of the impact: the larger of vehicle speed and change
        minDelta = 40,         -- km/h change of the velocity vector inside the window
        minRatio = 0.45,       -- the change must be at least this share of the speed (0.45 = 45 %)
        window = 220,          -- ms window in which the change is measured
        -- FORCE (how the occupant is thrown): independent from the threshold. The
        -- occupant keeps their inertia, opposite to the vehicle's velocity change.
        horizontalForce = 1.0, -- share of that inertia (1.0 = all of it)
        verticalForce = 2.5,   -- m/s upward impulse
        ragdoll = 4000,        -- ms of ragdoll after the ejection
        damageEnabled = true,  -- extra damage after the ejection
        damage = 10,           -- extra damage points
        cooldown = 5000,       -- ms of protection between ejections
        -- Where it is allowed. Cars only by default (never bicycles).
        categories = { 'car' },  -- car | motorcycle | boat | plane | heli
        allowModels = {},        -- model names allowed even if their category is not
        denyModels = {},         -- model names that never eject
    },
}

------------------------------------------------------------------------------
-- Lights and indicators (players can rebind keys in Settings → Key Bindings → FiveM)
------------------------------------------------------------------------------
Config.Lights = {
    key = 'H',              -- tap: lights · hold: high beams
    longPress = 350,        -- ms to count as a long press
    leftKey = 'LEFT',
    rightKey = 'RIGHT',
    hazardKey = 'DOWN',
}

------------------------------------------------------------------------------
-- Cruise control (land vehicles only; never aircraft or boats)
------------------------------------------------------------------------------
Config.Cruise = {
    key = 'Y',
    upKey = 'PAGEUP',
    downKey = 'PAGEDOWN',
    step = 5,               -- in the player's unit (km/h or mph)
    minSpeed = 30,          -- km/h
    maxAirTime = 1200,      -- ms airborne before cancelling
}

------------------------------------------------------------------------------
-- Engine
------------------------------------------------------------------------------
Config.Engine = {
    key = 'G',
    -- Authorisation: 'auto' uses qbx_vehiclekeys:HasKeys when it is started;
    -- 'none' always allows the driver. You can also set your own function, e.g.
    -- (replace with the real export of your keys resource):
    --   authorize = function(vehicle) return exports.your_keys:HasKey(vehicle) end
    -- Other resources can register theirs with
    --   exports.vortexlabs_carhud:SetEngineAuthorizer(function(vehicle) ... end)
    authorize = 'auto',
}

------------------------------------------------------------------------------
-- Built-in nitro. No vehicle has nitro until it is installed (admin command or
-- server exports). The charge lives on the server.
------------------------------------------------------------------------------
Config.Nitro = {
    key = 'LSHIFT',          -- hold to use
    defaultCapacity = 100.0, -- capacity when installed without a value
    maxCapacity = 300.0,
    consumption = 12.5,      -- units per second of use
    minToActivate = 5.0,     -- minimum charge to activate
    cooldown = 1500,         -- ms between activations
    power = 2.0,             -- power multiplier while accelerating
    exhaustFx = true,        -- local exhaust flames
    persist = true,          -- save installation and charge in data/nitro.json (by plate)
    command = 'carhudnitro', -- /carhudnitro equip|refill|remove|info
}

------------------------------------------------------------------------------
-- Fuel: read only. This resource never writes the level or the consumption.
------------------------------------------------------------------------------
Config.Fuel = {
    -- 'auto' | 'native' | 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel'
    provider = 'auto',
    -- Scale of the native value (GetVehicleFuelLevel) in 'native' mode:
    -- 'tank' = litres relative to the handling's fPetrolTankVolume (base game)
    -- 'percent' = 0–100 (servers where another script writes percentages)
    nativeScale = 'tank',
    decor = '_FUEL_LEVEL',   -- LegacyFuel / cdn-fuel decorator (their Config.FuelDecor)
}

-- Warning thresholds (percent)
Config.Warnings = {
    fuel = 15,
    engine = 35,
}

------------------------------------------------------------------------------
-- Limits for player settings
------------------------------------------------------------------------------
Config.Player = {
    allowUnit = true,
    allowColor = true,
    allowLayout = true,
    allowModules = true,
    scaleMin = 0.8,          -- HUD scale range players can choose (80–150 %)
    scaleMax = 1.5,
    opacityMin = 0.4,        -- minimum opacity of the speedometer (0–1)
    maxVolume = 1.0,         -- maximum sound volume (0–1)
    defaultVolume = 0.6,
    settingsKey = '',        -- optional key to open the settings ('' = /carhud only)
    command = 'carhud',
}

------------------------------------------------------------------------------
-- Admin permissions. The server console is always allowed.
------------------------------------------------------------------------------
Config.Permissions = {
    ace = 'vortexlabs_carhud.admin', -- add_ace group.admin vortexlabs_carhud.admin allow
    frameworkGroups = { 'admin', 'god', 'superadmin' },
}

------------------------------------------------------------------------------
-- In-game admin menu (/carhudadmin). Uses the same permissions (ACE
-- vortexlabs_carhud.admin or a framework admin group); the server checks them on
-- every open and every change. Changes are saved in data/admin.json (no
-- database) and take priority over this file; "Restore defaults" returns to
-- the values in config.lua.
------------------------------------------------------------------------------
Config.Admin = {
    command = 'carhudadmin',
    crashDiagCommand = 'carhudcrash', -- ejection diagnostics (admins only, off by default)
    persist = true,
}
