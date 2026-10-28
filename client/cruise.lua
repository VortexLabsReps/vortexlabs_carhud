-- Control de crucero terrestre. Mantiene la velocidad dosificando la entrada de
-- acelerador (SetControlNormal) fotograma a fotograma: no toca límites de
-- velocidad ni handling, así que al cancelar no queda nada que restaurar.
-- Nunca actúa en aeronaves (el perfil lo impide).
local Util = CarHud.Util
local S = CarHud.State
local cfg = Config.Cruise

local Cruise = { target = 0.0, vehicle = 0 }
local ACCELERATE, BRAKE, HANDBRAKE = 71, 72, 76
local airSince = nil

local function unitFactor()
    return (S.settings and S.settings.unit == 'mph') and Util.MPH or Util.KMH
end

function Cruise.cancel(notify)
    if Cruise.target <= 0 then return end
    Cruise.target = 0.0
    Cruise.vehicle = 0
    airSince = nil
    CarHud.Frame.clear('cruise')
    if notify then CarHud.notify('notice.cruiseOff', 'info') end
    CarHud.Telemetry.poke()
end

local function step()
    local vehicle = Cruise.vehicle
    if not CarHud.Vehicle.isDriving(vehicle) or S.veh ~= vehicle then return Cruise.cancel(false) end
    if IsControlPressed(0, BRAKE) or IsControlPressed(0, HANDBRAKE) then return Cruise.cancel(true) end
    if not GetIsVehicleEngineRunning(vehicle) or IsEntityDead(vehicle) or GetVehicleCurrentGear(vehicle) == 0 then
        return Cruise.cancel(true)
    end
    if IsEntityInAir(vehicle) then
        airSince = airSince or GetGameTimer()
        if GetGameTimer() - airSince > cfg.maxAirTime then return Cruise.cancel(true) end
        return
    end
    airSince = nil
    if IsEntityInWater(vehicle) and S.profile.category ~= 'boat' then return Cruise.cancel(true) end

    local speed = GetEntitySpeed(vehicle)
    if speed < Cruise.target * 0.5 and HasEntityCollidedWithAnything(vehicle) then return Cruise.cancel(true) end
    if IsControlPressed(0, ACCELERATE) then return end -- el jugador acelera por encima del crucero

    local deficit = Cruise.target - speed
    if deficit > -0.25 then
        SetControlNormal(0, ACCELERATE, Util.clamp(0.3 + deficit * 0.35, 0.0, 1.0))
    end
end

function Cruise.toggle()
    if Cruise.target > 0 then return Cruise.cancel(true) end
    local profile = S.profile
    if not profile or not profile.cruise or not CarHud.Vehicle.isDriving(S.veh) or IsPauseMenuActive() then return end
    local vehicle = S.veh
    if not GetIsVehicleEngineRunning(vehicle) or IsEntityDead(vehicle) or GetVehicleCurrentGear(vehicle) == 0 then return end
    if IsEntityInAir(vehicle) then return end

    local speed = GetEntitySpeed(vehicle)
    local minimum = cfg.minSpeed / Util.KMH
    -- Solo hacia delante: la componente longitudinal debe ser positiva.
    if speed < minimum or GetEntitySpeedVector(vehicle, true).y <= 0 then
        CarHud.notify('notice.cruiseMin', 'warn', { speed = minimum })
        return
    end
    Cruise.target = speed
    Cruise.vehicle = vehicle
    CarHud.Frame.set('cruise', step)
    CarHud.notify('notice.cruiseOn', 'info', { speed = speed })
    CarHud.Telemetry.poke()
end

-- Ajuste en pasos de la unidad del jugador (5 km/h o 5 mph por defecto).
function Cruise.adjust(direction)
    if Cruise.target <= 0 or not CarHud.Vehicle.isDriving(Cruise.vehicle) then return end
    local factor = unitFactor()
    local current = Cruise.target * factor
    local nextValue = (math.floor(current / cfg.step + 0.5) + direction) * cfg.step
    local minimum = cfg.minSpeed / Util.KMH
    local maximum = (S.scaleKmh or 260) / Util.KMH
    Cruise.target = Util.clamp(nextValue / factor, minimum, maximum)
    CarHud.notify('notice.cruiseOn', 'info', { speed = Cruise.target })
    CarHud.Telemetry.poke()
end

CarHud.on('exit', function() Cruise.cancel(false) end)
CarHud.on('seat', function() if not S.isDriver then Cruise.cancel(false) end end)
CarHud.on('enter', function() Cruise.cancel(false) end)
CarHud.on('stop', function() Cruise.cancel(false) end)
CarHud.on('config', function()
    if not (CarHud.State.profile and CarHud.State.profile.cruise) then Cruise.cancel(false) end
end)

CarHud.Cruise = Cruise
