-- Lectura de combustible. Solo lectura: nunca escribe nivel, consumo ni repostaje.
-- Devuelve un porcentaje 0–100 (el 0 es depósito vacío), nil si el dato aún no
-- existe o false si el vehículo no usa combustible.
--
-- Interfaces verificadas en las fuentes oficiales:
--   ox_fuel    → statebag Entity(veh).state.fuel (0–100). No expone export de lectura.
--   LegacyFuel → exports.LegacyFuel:GetFuel(veh) = DecorGetFloat(veh, '_FUEL_LEVEL') (0–100)
--   cdn-fuel   → exports['cdn-fuel']:GetFuel(veh) = DecorGetFloat(veh, '_FUEL_LEVEL') (0–100)
-- GetFuel de LegacyFuel/cdn-fuel devuelve 0.0 si el decorador no existe; por eso
-- se comprueba DecorExistOn antes, para no confundir "sin dato" con "vacío".
local Util = CarHud.Util
local Fuel = { active = 'native', fallbackScale = nil }

local ORDER = { 'ox_fuel', 'cdn-fuel', 'LegacyFuel' }
local warned = {}
local failures = 0

local function started(resource)
    return GetResourceState(resource) == 'started'
end

local function usesFuel(vehicle)
    if DoesVehicleUseFuel then
        local ok, result = pcall(DoesVehicleUseFuel, vehicle)
        if ok and result == false then return false end
    end
    return true
end

local function fromDecorExport(resource)
    return function(vehicle)
        if not DecorExistOn(vehicle, Config.Fuel.decor) then return nil end
        return exports[resource]:GetFuel(vehicle)
    end
end

local PROVIDERS = {
    ox_fuel = function(vehicle)
        local value = Entity(vehicle).state.fuel
        if value == nil then return nil end
        return value
    end,
    LegacyFuel = fromDecorExport('LegacyFuel'),
    ['cdn-fuel'] = fromDecorExport('cdn-fuel'),
}

local function readNative(vehicle, scale)
    local level = Util.number(GetVehicleFuelLevel(vehicle))
    if not level then return nil end
    if scale == 'percent' then return Util.clamp(level, 0, 100) end
    local tank = Util.number(GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume'))
    if not tank or tank <= 0 then return false end
    return Util.clamp(level / tank * 100, 0, 100)
end

function Fuel.select()
    local wanted = Config.Fuel.provider
    local chosen = 'native'
    if wanted == 'auto' then
        for _, name in ipairs(ORDER) do
            if started(name) then chosen = name break end
        end
    elseif PROVIDERS[wanted] then
        if started(wanted) then
            chosen = wanted
        elseif not warned[wanted] then
            warned[wanted] = true
            print(CarHud.T('fuel_fallback', wanted))
        end
    end
    -- Si un proveedor estaba en uso y desaparece, el valor nativo que dejó está
    -- en porcentaje (los tres escriben 0–100 con SetVehicleFuelLevel).
    if chosen == 'native' and Fuel.active ~= 'native' then Fuel.fallbackScale = 'percent' end
    if chosen ~= 'native' then Fuel.fallbackScale = nil end
    Fuel.active = chosen
    failures = 0
    return chosen
end

function Fuel.read(vehicle)
    if not usesFuel(vehicle) then return false end
    local provider = PROVIDERS[Fuel.active]
    if provider then
        local ok, value = pcall(provider, vehicle)
        if ok then
            failures = 0
            if value == nil then return nil end
            value = Util.number(value)
            if value then return Util.clamp(value, 0, 100) end
            return nil
        end
        failures = failures + 1
        if failures >= 5 then
            Util.debug('fuel provider failing, falling back:', Fuel.active)
            Fuel.active = 'native'
            Fuel.fallbackScale = 'percent'
        end
    end
    return readNative(vehicle, Fuel.fallbackScale or Config.Fuel.nativeScale)
end

-- Arranque, parada o reinicio de un proveedor: se vuelve a elegir.
local function onResource(resource)
    if PROVIDERS[resource] then Fuel.select() end
end
AddEventHandler('onClientResourceStart', onResource)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == Fuel.active then
        Fuel.active = 'native'
        Fuel.fallbackScale = 'percent'
    end
    onResource(resource)
end)

-- Pruebas fuera del juego.
Fuel._readNative = readNative
Fuel._providers = PROVIDERS

Fuel.select()
CarHud.Fuel = Fuel
