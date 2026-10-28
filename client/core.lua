-- Estado compartido del cliente, eventos internos y bucle por fotograma bajo demanda.
local Util = CarHud.Util

CarHud.State = {
    ped = 0,
    veh = 0,          -- vehículo actual (0 = a pie)
    seat = nil,       -- asiento (-1 conductor)
    isDriver = false,
    profile = nil,    -- perfil efectivo (shared/profiles.lua)
    scaleKmh = 260,
    visible = false,  -- HUD visible ahora mismo
    locVisible = false, -- ubicación visible (siempre dentro del HUD visible)
    hiddenBy = {},    -- ocultaciones solicitadas por otros recursos
    settings = nil,   -- preferencias validadas del jugador
}

------------------------------------------------------------------------------
-- Eventos internos: enter(veh, seat) · exit(veh) · seat(seat) · stop()
------------------------------------------------------------------------------
local listeners = {}

function CarHud.on(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function CarHud.emit(event, ...)
    for _, fn in ipairs(listeners[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then CarHud.Util.warn('event:' .. event, ('%s: %s'):format(event, err)) end
    end
end

------------------------------------------------------------------------------
-- Bucle por fotograma: solo existe mientras alguna tarea lo necesita (controles
-- que hay que desactivar cada fotograma, crucero, nitro, detección de choques).
------------------------------------------------------------------------------
local Frame = { tasks = {}, added = {}, running = false, iterating = false, cost = nil }

function Frame.set(name, fn)
    -- Añadir claves durante un recorrido con pairs no está definido en Lua: se difiere.
    if Frame.iterating then Frame.added[name] = fn else Frame.tasks[name] = fn end
    if Frame.running then return end
    Frame.running = true
    CreateThread(function()
        while next(Frame.tasks) or next(Frame.added) do
            for name2, fn2 in pairs(Frame.added) do Frame.tasks[name2] = fn2 end
            Frame.added = {}
            local started = Frame.cost and Frame.now()
            Frame.iterating = true
            for taskName, task in pairs(Frame.tasks) do
                local ok, err = pcall(task)
                if not ok then
                    print('[vortexlabs_carhud] ' .. CarHud.T('task_error', taskName, tostring(err)))
                    Frame.tasks[taskName] = nil
                end
            end
            Frame.iterating = false
            if started and Frame.cost then Frame.cost(Frame.now() - started) end
            Wait(0)
        end
        Frame.running = false
    end)
end

function Frame.clear(name)
    Frame.tasks[name] = nil
    Frame.added[name] = nil
end

CarHud.Frame = Frame

------------------------------------------------------------------------------
-- Clasificación del vehículo
------------------------------------------------------------------------------
local Vehicle = {}

function Vehicle.category(vehicle)
    local model = GetEntityModel(vehicle)
    local override = CarHud.Profiles.modelOverride(model)
    return CarHud.Profiles.categoryFrom({
        override = override and override.category,
        class = GetVehicleClass(vehicle),
        bicycle = IsThisModelABicycle(model),
        heli = IsThisModelAHeli(model),
        plane = IsThisModelAPlane(model),
        boat = IsThisModelABoat(model),
        jetski = IsThisModelAJetski(model),
        bike = IsThisModelABike(model),
        quad = IsThisModelAQuadbike(model),
    }), override
end

function Vehicle.profile(vehicle)
    local category, override = Vehicle.category(vehicle)
    local profile = CarHud.Profiles.build(category, override)
    profile.scaleKmh = CarHud.Profiles.scaleKmh(profile, GetVehicleEstimatedMaxSpeed(vehicle))
    return profile
end

function Vehicle.seatOf(ped, vehicle)
    if GetPedInVehicleSeat(vehicle, -1) == ped then return -1 end
    for seat = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then return seat end
    end
    return nil
end

-- ¿Sigue siendo el conductor de este vehículo, vivo y dentro?
function Vehicle.isDriving(vehicle)
    local S = CarHud.State
    return vehicle ~= 0 and S.veh == vehicle and S.isDriver
        and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == S.ped
end

function Vehicle.speedKmh(vehicle)
    return GetEntitySpeed(vehicle) * Util.KMH
end

CarHud.Vehicle = Vehicle

-- Notificación de las funciones propias: franja del HUD o framework.
function CarHud.notify(key, kind, vars)
    if Config.Hud.notify == 'framework' and CarHud.Framework.notify(CarHud.NUI.translate(key, vars), kind) then
        return
    end
    CarHud.NUI.send({ t = 'notice', key = key, kind = kind, vars = vars })
end
