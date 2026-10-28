-- Luces e intermitentes propios. Cada acción parte del estado real del vehículo
-- (GetVehicleLightsState / GetVehicleIndicatorLights), así el HUD siempre refleja
-- lo que se ve. La tecla nativa de luces (INPUT_VEH_HEADLIGHT) se desactiva solo
-- mientras se conduce un vehículo compatible, para evitar la doble alternancia.
local S = CarHud.State
local cfg = Config.Lights

local Lights = {}
local HEADLIGHT_CONTROL = 74     -- INPUT_VEH_HEADLIGHT
local touched = {}               -- vehículos cuyo modo de luces hemos fijado
local pressId = 0
local pressConsumed = true

local function truthy(value)
    return value == true or value == 1
end

function Lights.state(vehicle)
    local _, lightsOn, highOn = GetVehicleLightsState(vehicle)
    if truthy(highOn) and truthy(lightsOn) then return 'high' end
    if truthy(lightsOn) then return 'low' end
    return 'off'
end

local function canControl(kind)
    local profile = S.profile
    if not profile or not profile[kind] then return false end
    if IsPauseMenuActive() then return false end
    return CarHud.Vehicle.isDriving(S.veh)
end

function Lights.toggleLow()
    local vehicle = S.veh
    if Lights.state(vehicle) == 'off' then
        SetVehicleLights(vehicle, 2)        -- forzar encendidas
    else
        SetVehicleFullbeam(vehicle, false)
        SetVehicleLights(vehicle, 1)        -- forzar apagadas
    end
    touched[vehicle] = true
    CarHud.Telemetry.poke()
end

function Lights.toggleHigh()
    local vehicle = S.veh
    local state = Lights.state(vehicle)
    if state == 'high' then
        SetVehicleFullbeam(vehicle, false)
    else
        if state == 'off' then SetVehicleLights(vehicle, 2) end
        SetVehicleFullbeam(vehicle, true)
    end
    touched[vehicle] = true
    CarHud.Telemetry.poke()
end

-- Pulsación corta: luces. Mantener: largas.
function Lights.press()
    if not canControl('lights') then return end
    pressId = pressId + 1
    pressConsumed = false
    local id = pressId
    SetTimeout(cfg.longPress, function()
        if id == pressId and not pressConsumed and canControl('lights') then
            pressConsumed = true
            Lights.toggleHigh()
        end
    end)
end

function Lights.release()
    if pressConsumed then return end
    pressConsumed = true
    if canControl('lights') then Lights.toggleLow() end
end

-- Intermitentes: 'left' | 'right' | 'hazard'. Bits del juego: 1 izquierda, 2 derecha.
function Lights.indicator(which)
    if not canControl('indicators') then return end
    local vehicle = S.veh
    local current = GetVehicleIndicatorLights(vehicle)
    local left, right
    if which == 'hazard' then
        local on = current ~= 3
        left, right = on, on
    elseif which == 'left' then
        left, right = current ~= 1, false
    else
        left, right = false, current ~= 2
    end
    SetVehicleIndicatorLights(vehicle, 1, left)
    SetVehicleIndicatorLights(vehicle, 0, right)
    CarHud.Telemetry.poke()
end

local function frameTask()
    DisableControlAction(0, HEADLIGHT_CONTROL, true)
end

local function refresh()
    if S.isDriver and S.profile and S.profile.lights then
        CarHud.Frame.set('lights', frameTask)
    else
        CarHud.Frame.clear('lights')
    end
end

CarHud.on('enter', refresh)
CarHud.on('seat', refresh)
CarHud.on('config', refresh)
CarHud.on('exit', function()
    pressConsumed = true
    CarHud.Frame.clear('lights')
end)

-- Al detener el recurso se devuelve el control de luces al juego.
CarHud.on('stop', function()
    for vehicle in pairs(touched) do
        if DoesEntityExist(vehicle) then SetVehicleLights(vehicle, 0) end
    end
    touched = {}
end)

CarHud.Lights = Lights
