-- Perfiles de vehículo: categoría, matriz de funciones, escala y conversiones.
-- Funciones puras (sin natives) para poder probarlas fuera del juego.
local Util = CarHud.Util
local Profiles = {}

-- Claves de función que existen en un perfil. Todo lo que no está a true queda a false.
Profiles.FEATURE_KEYS = {
    'gear', 'rpm', 'throttle', 'fuel', 'engine', 'nitro',
    'seatbelt', 'lights', 'indicators', 'cruise', 'engineToggle',
    'altitudeMsl', 'altitudeAgl', 'verticalSpeed',
}

-- Interruptores globales de Config.Features que gobiernan cada clave del perfil.
local GLOBAL_GATES = {
    seatbelt = 'seatbelt', lights = 'lights', indicators = 'indicators',
    cruise = 'cruise', engineToggle = 'engine', nitro = 'nitro',
}

local modelIndex

-- Indexa Config.Models por hash. hashFn = GetHashKey en el juego.
function Profiles.indexModels(hashFn)
    modelIndex = {}
    for name, data in pairs(Config.Models or {}) do
        if type(name) == 'string' and type(data) == 'table' then
            modelIndex[hashFn(name)] = data
        elseif type(name) == 'number' and type(data) == 'table' then
            modelIndex[name] = data
        end
    end
end

function Profiles.modelOverride(modelHash)
    return modelIndex and modelIndex[modelHash] or nil
end

-- info = { override, class, bicycle, heli, plane, boat, jetski, bike, quad }
function Profiles.categoryFrom(info)
    if info.override and Config.Categories[info.override] then return info.override end
    if info.bicycle or info.class == 13 then return 'bicycle' end
    if info.heli or info.class == 15 then return 'heli' end
    if info.plane or info.class == 16 then return 'plane' end
    if info.boat or info.jetski or info.class == 14 then return 'boat' end
    if info.class == 21 then return 'train' end
    if info.bike or info.quad or info.class == 8 then return 'motorcycle' end
    return 'car'
end

-- Construye el perfil efectivo: categoría + excepción del modelo + interruptores globales.
function Profiles.build(category, override)
    local profile = { category = category }
    for key, value in pairs(Config.Categories[category] or { hud = false }) do profile[key] = value end
    if override then
        for key, value in pairs(override) do
            if key ~= 'category' then profile[key] = value end
        end
    end

    profile.hud = profile.hud == true
    for _, key in ipairs(Profiles.FEATURE_KEYS) do
        profile[key] = profile.hud and profile[key] == true
    end
    -- Testigos que reflejan el estado real del vehículo aunque el control propio
    -- esté desactivado globalmente (el jugador sigue usando las teclas nativas).
    profile.show = { lights = profile.lights, indicators = profile.indicators and not profile.aircraft }
    for key, gate in pairs(GLOBAL_GATES) do
        if Config.Features[gate] == false then profile[key] = false end
    end

    -- Las aeronaves nunca reciben funciones terrestres: el crucero no es un piloto automático.
    if profile.aircraft then
        profile.cruise = false
        profile.seatbelt = false
        profile.nitro = false
        profile.gear = false
        profile.indicators = false
    else
        profile.altitudeMsl, profile.altitudeAgl, profile.verticalSpeed = false, false, false
    end
    return profile
end

-- Escala máxima del arco en km/h. estimatedMaxMs = GetVehicleEstimatedMaxSpeed (m/s).
function Profiles.scaleKmh(profile, estimatedMaxMs)
    local fixed = Util.number(profile.maxSpeed)
    if fixed and fixed > 0 then return fixed end
    local estimated = Util.number(estimatedMaxMs)
    if not estimated or estimated <= 1 then return profile.fallbackMax or 260 end
    local kmh = math.ceil(estimated * Util.KMH * 1.15 / 20) * 20
    return Util.clamp(kmh, profile.autoMin or 120, profile.autoMax or 400)
end

-- Pedal de potencia (0–1) a partir de GetVehicleThrottleOffset. En marcha atrás
-- el juego lo reporta negativo; con marcha adelante un valor negativo es freno.
function Profiles.pedal(offset, gear)
    offset = Util.number(offset) or 0
    if gear == 0 then return Util.clamp(math.abs(offset), 0, 1) end
    return Util.clamp(offset, 0, 1)
end

CarHud.Profiles = Profiles
