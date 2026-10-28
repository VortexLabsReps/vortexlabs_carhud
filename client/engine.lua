-- Encendido y apagado propios, solo para el conductor y respetando los permisos
-- del sistema de llaves (punto de integración: Config.Engine.authorize o el
-- export SetEngineAuthorizer).
local S = CarHud.State
local cfg = Config.Engine

local Engine = {}
local authorizer = nil
local busy = false

local function authorized(vehicle)
    local check = authorizer or (type(cfg.authorize) == 'function' and cfg.authorize) or nil
    if check then
        local ok, result = pcall(check, vehicle)
        if not ok then
            CarHud.Util.warn('engine:authorize', CarHud.T('engine_auth_error', tostring(result)))
            return false
        end
        return result ~= false
    end
    if cfg.authorize == 'auto' and GetResourceState('qbx_vehiclekeys') == 'started' then
        local ok, result = pcall(function() return exports.qbx_vehiclekeys:HasKeys(vehicle) end)
        if ok then return result == true end
        CarHud.Util.debug('qbx_vehiclekeys:HasKeys failed:', tostring(result))
    end
    return true
end

function Engine.toggle()
    if busy then return end
    local profile = S.profile
    if not profile or not profile.engineToggle or not CarHud.Vehicle.isDriving(S.veh) or IsPauseMenuActive() then return end
    local vehicle = S.veh
    if GetIsVehicleEngineRunning(vehicle) then
        SetVehicleEngineOn(vehicle, false, false, true)
        CarHud.Cruise.cancel(false)
        CarHud.Nitro.release()
        CarHud.Telemetry.poke()
        return
    end
    busy = true
    -- HasKeys puede consultar al servidor: se evalúa en su propio hilo.
    CreateThread(function()
        local allowed = authorized(vehicle)
        busy = false
        if not CarHud.Vehicle.isDriving(vehicle) then return end
        if not allowed then
            CarHud.notify('notice.noKeys', 'danger')
            return
        end
        SetVehicleEngineOn(vehicle, true, false, false)
        CarHud.Telemetry.poke()
    end)
end

exports('SetEngineAuthorizer', function(fn)
    authorizer = fn
end)

CarHud.Engine = Engine
