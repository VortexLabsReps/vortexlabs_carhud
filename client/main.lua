-- Ciclo de vida del cliente: detección de entrada/salida/asiento, componentes
-- nativos ocultos mientras el HUD está visible, exports y parada limpia.
local S = CarHud.State
local Vehicle = CarHud.Vehicle
local Telemetry = CarHud.Telemetry

CarHud.Profiles.indexModels(GetHashKey)

------------------------------------------------------------------------------
-- Componentes nativos que se solapan con el reloj (solo mientras se ve el HUD)
------------------------------------------------------------------------------
local hiddenComponents = Config.Hud.hideNativeComponents or {}

local function hudFrame()
    for i = 1, #hiddenComponents do HideHudComponentThisFrame(hiddenComponents[i]) end
end

CarHud.on('visibility', function(visible)
    if visible and #hiddenComponents > 0 then CarHud.Frame.set('hud', hudFrame) else CarHud.Frame.clear('hud') end
end)

------------------------------------------------------------------------------
-- Entrada, salida y cambio de asiento
------------------------------------------------------------------------------
local function enter(vehicle, seat)
    S.veh = vehicle
    S.seat = seat
    S.isDriver = seat == -1
    S.profile = Vehicle.profile(vehicle)
    S.scaleKmh = S.profile.scaleKmh
    CarHud.emit('enter', vehicle, seat)
    if S.profile.hud then Telemetry.start(vehicle) else Telemetry.stop() end
end

local function leave()
    local vehicle = S.veh
    Telemetry.stop()
    CarHud.emit('exit', vehicle)
    S.veh, S.seat, S.isDriver, S.profile = 0, nil, false, nil
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        S.ped = ped
        local vehicle = 0
        if IsPedInAnyVehicle(ped, false) then vehicle = GetVehiclePedIsIn(ped, false) end
        if vehicle ~= 0 and not DoesEntityExist(vehicle) then vehicle = 0 end

        if vehicle ~= S.veh then
            if S.veh ~= 0 then leave() end
            if vehicle ~= 0 then enter(vehicle, Vehicle.seatOf(ped, vehicle)) end
        elseif vehicle ~= 0 then
            local seat = Vehicle.seatOf(ped, vehicle)
            if seat ~= S.seat then
                S.seat = seat
                S.isDriver = seat == -1
                CarHud.emit('seat', seat)
            end
        end
        Wait(vehicle ~= 0 and 250 or Config.Rates.idle)
    end
end)

------------------------------------------------------------------------------
-- Notificaciones del servidor (administración del nitro)
------------------------------------------------------------------------------
RegisterNetEvent('vortexlabs_carhud:notify', function(text, kind)
    if type(text) ~= 'string' then return end
    if Config.Hud.notify == 'framework' and CarHud.Framework.notify(text, kind) then return end
    CarHud.NUI.send({ t = 'notice', text = text, kind = kind or 'info', ms = 3500 })
end)

------------------------------------------------------------------------------
-- Exports de cliente
------------------------------------------------------------------------------
exports('IsSeatbeltOn', function()
    return CarHud.Seatbelt.applies() and CarHud.Seatbelt.isOn() or false
end)

-- Otro recurso puede ocultar el HUD (p. ej. durante una cinemática). Cada
-- recurso tiene su propia ocultación y se libera sola si ese recurso se detiene.
exports('SetHudVisible', function(visible)
    local resource = GetInvokingResource() or 'unknown'
    S.hiddenBy[resource] = (visible == false) or nil
end)

exports('IsHudVisible', function() return S.visible end)
exports('GetCruiseSpeed', function() return CarHud.Cruise.target end)
exports('OpenSettings', function() CarHud.Menu.show() end)

AddEventHandler('onClientResourceStop', function(resource)
    S.hiddenBy[resource] = nil
end)

------------------------------------------------------------------------------
-- Parada del recurso: nada de estados, efectos ni controles bloqueados.
-- Los bucles por fotograma mueren con el recurso (controles y potencia vuelven
-- solos); aquí se restauran los estados persistentes del juego.
------------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CarHud.emit('stop')
    if CarHud.Menu.open then SetNuiFocus(false, false) end
end)

CreateThread(function()
    print(CarHud.T('framework_detected', CarHud.Framework.name, CarHud.Fuel.active, CarHud.Seatbelt.mode))
end)
