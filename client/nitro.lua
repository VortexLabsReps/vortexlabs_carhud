-- Nitro propio (cliente). La carga y el equipamiento viven en el servidor y se
-- replican en el statebag del vehículo; el cliente solo pide activar/desactivar
-- y aplica el efecto mientras el servidor lo confirma. La NUI solo lo muestra.
-- El efecto es SetVehicleCheatPowerIncrease, que hay que renovar cada
-- fotograma: si el recurso se detiene o el bucle termina, desaparece solo.
local Util = CarHud.Util
local S = CarHud.State
local cfg = Config.Nitro

local Nitro = {}
local STATE_KEY = 'fcarhud_nitro'
local holding = false
local requested = false
local lastRequest = 0
local synced = {}
local fx = { offsets = nil, last = 0, loaded = false }
local EXHAUSTS = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6' }

function Nitro.data(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local data = Entity(vehicle).state[STATE_KEY]
    if type(data) == 'table' and Util.number(data.cap) and data.cap > 0 then return data end
    return nil
end

-- Para el HUD: { amt, cap, on } o false si no hay nitro (el módulo se oculta).
function Nitro.display(vehicle)
    if not S.profile or not S.profile.nitro then return false end
    local data = Nitro.data(vehicle)
    if not data then return false end
    return { amt = Util.round(Util.number(data.amt) or 0, 1), cap = Util.round(data.cap, 1), on = data.on == true }
end

local function canUse()
    local profile = S.profile
    if not profile or not profile.nitro then return false end
    local vehicle = S.veh
    return CarHud.Vehicle.isDriving(vehicle) and GetIsVehicleEngineRunning(vehicle) and not IsEntityDead(vehicle)
end

local function netId(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then return nil end
    return VehToNet(vehicle)
end

------------------------------------------------------------------------------
-- Efecto local
------------------------------------------------------------------------------
local function loadFx()
    if fx.loaded or not cfg.exhaustFx then return end
    RequestNamedPtfxAsset('core')
    fx.loaded = true
end

local function exhaustOffsets(vehicle)
    local list = {}
    for _, bone in ipairs(EXHAUSTS) do
        local index = GetEntityBoneIndexByName(vehicle, bone)
        if index ~= -1 then
            local world = GetWorldPositionOfEntityBone(vehicle, index)
            list[#list + 1] = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
        end
    end
    return list
end

local function exhaustFx(vehicle)
    if not cfg.exhaustFx or not HasNamedPtfxAssetLoaded('core') then return end
    local now = GetGameTimer()
    if now - fx.last < 120 then return end
    fx.last = now
    fx.offsets = fx.offsets or exhaustOffsets(vehicle)
    for _, offset in ipairs(fx.offsets) do
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedOnEntity('veh_backfire', vehicle, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
end

local function effectStep()
    local vehicle = S.veh
    local data = Nitro.data(vehicle)
    if not data or data.on ~= true then
        fx.offsets = nil
        return CarHud.Frame.clear('nitro')
    end
    if not holding or not canUse() then
        Nitro.release()
        return
    end
    if GetVehicleThrottleOffset and GetVehicleThrottleOffset(vehicle) > 0.1 then
        SetVehicleCheatPowerIncrease(vehicle, cfg.power)
        exhaustFx(vehicle)
    end
end

------------------------------------------------------------------------------
-- Entrada
------------------------------------------------------------------------------
function Nitro.press()
    holding = true
    if requested or not canUse() then return end
    local vehicle = S.veh
    local data = Nitro.data(vehicle)
    if not data or (Util.number(data.amt) or 0) < cfg.minToActivate then return end
    local now = GetGameTimer()
    if now - lastRequest < 250 then return end
    local id = netId(vehicle)
    if not id then return end
    lastRequest = now
    requested = true
    loadFx()
    TriggerServerEvent('vortexlabs_carhud:nitro:start', id)
end

function Nitro.release()
    holding = false
    if not requested then return end
    requested = false
    local vehicle = S.veh ~= 0 and S.veh or nil
    local id = vehicle and DoesEntityExist(vehicle) and netId(vehicle)
    TriggerServerEvent('vortexlabs_carhud:nitro:stop', id or 0)
end

-- El servidor confirma (o retira) la activación a través del statebag.
AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or entity ~= S.veh then return end
    if type(value) == 'table' and value.on == true and holding then
        CarHud.Frame.set('nitro', effectStep)
    elseif type(value) ~= 'table' or value.on ~= true then
        requested = false
    end
    CarHud.Telemetry.poke()
end)

------------------------------------------------------------------------------
-- Ciclo de vida
------------------------------------------------------------------------------
-- Al ponerse al volante se pide al servidor que publique el nitro guardado de
-- esta matrícula (si lo hay). Una vez por vehículo y entrada.
local function requestSync()
    local profile = S.profile
    if not profile or not profile.nitro or not S.isDriver then return end
    local id = netId(S.veh)
    if not id or synced[id] then return end
    synced[id] = true
    TriggerServerEvent('vortexlabs_carhud:nitro:sync', id)
end

CarHud.on('enter', requestSync)
CarHud.on('seat', requestSync)
CarHud.on('exit', function()
    synced = {}
    Nitro.release()
    CarHud.Frame.clear('nitro')
    fx.offsets = nil
end)
CarHud.on('config', function()
    if not (S.profile and S.profile.nitro) then
        Nitro.release()
        CarHud.Frame.clear('nitro')
    end
end)
CarHud.on('stop', function()
    if requested then Nitro.release() end
end)

CarHud.Nitro = Nitro
