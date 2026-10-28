-- Entorno FiveM simulado para el banco de pruebas: planificador con tiempo
-- virtual (fotogramas de 16 ms), eventos, exports, statebags, KVP, NUI y un
-- mundo mínimo de vehículos. No pretende reproducir la física del juego: sirve
-- para ejercitar la lógica del recurso con estados controlados.
local F = { now = 0, frames = 0, frameMs = 16, threads = {}, prints = {} }
local R = FD_ROOT

json = dofile(R .. '/dev/json.lua')

local function hash(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + s:lower():byte(i)) & 0xFFFFFFFF end
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end
GetHashKey = hash
F.hash = hash

local realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    table.insert(F.prints, table.concat(parts, ' '))
end
F.realPrint = realPrint

------------------------------------------------------------------------------
-- Planificador
------------------------------------------------------------------------------
function CreateThread(fn)
    table.insert(F.threads, { co = coroutine.create(fn), wake = F.now })
end
Citizen = { CreateThread = CreateThread }
function Wait(ms) coroutine.yield(ms or 0) end
function SetTimeout(ms, fn) CreateThread(function() Wait(ms) fn() end) end
function GetGameTimer() return F.now end
function GetFrameCount() return F.frames end

function F.run(ms)
    local target = F.now + (ms or 0)
    repeat
        F.now = F.now + F.frameMs
        F.frames = F.frames + 1
        F.disabled = {}
        F.injected = {}
        if F.onFrame then F.onFrame() end
        local list = F.threads
        F.threads = {}
        for _, t in ipairs(list) do
            if coroutine.status(t.co) ~= 'dead' then
                if t.wake <= F.now then
                    local ok, wait = coroutine.resume(t.co)
                    if not ok then error('hilo: ' .. tostring(wait)) end
                    if coroutine.status(t.co) ~= 'dead' then
                        t.wake = F.now + (wait or 0)
                        table.insert(F.threads, t)
                    end
                else
                    table.insert(F.threads, t)
                end
            end
        end
        if F.afterFrame then F.afterFrame() end
    until F.now >= target
end

------------------------------------------------------------------------------
-- Eventos, comandos, teclas y recursos
------------------------------------------------------------------------------
F.handlers, F.commands, F.keymaps, F.serverEvents, F.clientEvents = {}, {}, {}, {}, {}
F.resources = { vortexlabs_carhud = 'started' }
F.resourceName = 'vortexlabs_carhud'

function AddEventHandler(name, fn)
    F.handlers[name] = F.handlers[name] or {}
    table.insert(F.handlers[name], fn)
end
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function TriggerEvent(name, ...)
    for _, fn in ipairs(F.handlers[name] or {}) do fn(...) end
end
function F.netEvent(src, name, ...)
    for _, fn in ipairs(F.handlers[name] or {}) do
        source = src
        fn(...)
    end
    source = nil
end
function TriggerServerEvent(name, ...) table.insert(F.serverEvents, { name = name, args = { ... } }) end
function TriggerClientEvent(name, target, ...) table.insert(F.clientEvents, { name = name, target = target, args = { ... } }) end
function RegisterCommand(name, fn) F.commands[name] = fn end
function RegisterKeyMapping(command, description, mapper, key) F.keymaps[command] = { description = description, key = key } end
function F.command(name, src, args) F.commands[name](src or 0, args or {}) end
function GetResourceState(name) return F.resources[name] or 'missing' end
function GetCurrentResourceName() return F.resourceName end
function GetInvokingResource() return F.invoking end
function GetResourceMetadata() return '1.0.0' end

function F.startResource(name)
    F.resources[name] = 'started'
    TriggerEvent('onClientResourceStart', name)
    TriggerEvent('onResourceStart', name)
end
function F.stopResource(name)
    F.resources[name] = 'stopping'
    TriggerEvent('onClientResourceStop', name)
    TriggerEvent('onResourceStop', name)
    F.resources[name] = 'stopped'
end

-- exports: propios (exports('x', fn)) y ajenos (F.extExports[recurso][fn])
F.ownExports, F.extExports = {}, {}
exports = setmetatable({}, {
    __call = function(_, name, fn) F.ownExports[name] = fn end,
    __index = function(_, resource)
        return setmetatable({}, {
            __index = function(_, fnName)
                return function(_, ...)
                    local res = F.extExports[resource]
                    if not res or not res[fnName] then error(('export %s:%s no disponible'):format(resource, fnName)) end
                    return res[fnName](...)
                end
            end,
        })
    end,
})

------------------------------------------------------------------------------
-- Statebags
------------------------------------------------------------------------------
F.bags, F.bagHandlers = {}, {}

function AddStateBagChangeHandler(key, bagFilter, fn)
    table.insert(F.bagHandlers, { key = key, bag = bagFilter, fn = fn })
end

local function bagProxy(bagName)
    F.bags[bagName] = F.bags[bagName] or {}
    return setmetatable({
        set = function(_, key, value, replicated)
            F.bags[bagName][key] = value
            for _, h in ipairs(F.bagHandlers) do
                if (h.key == nil or h.key == key) and (h.bag == nil or h.bag == bagName) then h.fn(bagName, key, value, 0, replicated) end
            end
        end,
    }, {
        __index = function(_, key) return F.bags[bagName][key] end,
        __newindex = function(_, key, value) F.bags[bagName][key] = value end,
    })
end
F.bagProxy = bagProxy

function Entity(handle)
    local v = F.vehicles[handle]
    local name = 'entity:' .. tostring(v and v.net or handle)
    return { state = bagProxy(name) }
end
LocalPlayer = { state = bagProxy('player:1') }
GlobalState = bagProxy('global')

function GetEntityFromStateBagName(bagName)
    local net = tonumber(bagName:match('^entity:(%d+)$'))
    for handle, v in pairs(F.vehicles) do
        if v.net == net then return handle end
    end
    return 0
end

------------------------------------------------------------------------------
-- KVP y NUI
------------------------------------------------------------------------------
F.kvp, F.nui, F.nuiCallbacks = {}, {}, {}
function GetResourceKvpString(key) return F.kvp[key] end
function SetResourceKvp(key, value) F.kvp[key] = value end
function DeleteResourceKvp(key) F.kvp[key] = nil end
function SendNUIMessage(msg) table.insert(F.nui, json.decode(json.encode(msg))) end
function RegisterNUICallback(name, fn) F.nuiCallbacks[name] = fn end
F.focus = { false, false }
function SetNuiFocus(a, b) F.focus = { a, b } end
function F.nuiCall(name, data)
    local result
    F.nuiCallbacks[name](data or {}, function(r) result = r end)
    return result
end
function F.nuiOf(kind)
    local out = {}
    for _, m in ipairs(F.nui) do if m.t == kind then out[#out + 1] = m end end
    return out
end
function F.lastNui(kind)
    for i = #F.nui, 1, -1 do if F.nui[i].t == kind then return F.nui[i] end end
end

------------------------------------------------------------------------------
-- Mundo: jugador y vehículos
------------------------------------------------------------------------------
F.ped = 1
F.pedState = { dead = false, flags = { [32] = true }, coords = { x = 0, y = 0, z = 30 }, ragdoll = false, damage = 0 }
F.vehicles = {}
F.pedVehicle = 0
F.ui = { pause = false, faded = false, hudHidden = false, radarHidden = false, safe = 1.0, aspect = 16 / 9 }
F.input = { pressed = {}, just = {} }
F.disabled, F.injected = {}, {}
F.particles = 0

local nextHandle, nextNet = 100, 500

local DEFAULTS = {
    model = 'adder', class = 7, kind = {}, speed = 0.0, vel = { x = 0, y = 0, z = 0 }, coords = { x = 0, y = 0, z = 30 },
    agl = 0.5, rpm = 0.2, gear = 1, throttle = 0.0, engineOn = true, engineHealth = 1000.0, fuelLevel = 65.0, tank = 65.0,
    usesFuel = true, lightsMode = 0, lightsOn = false, high = false, ind = 0, turbo = false, turboP = 0.0, dead = false,
    decors = {}, inAir = false, inWater = false, collided = false, plate = 'VXLB 001 ', estMax = 60.0, type = 'automobile',
    passengers = 3, power = 0, forward = 1.0, networked = true,
}

function F.spawn(opts)
    nextHandle = nextHandle + 1
    nextNet = nextNet + 1
    local v = {}
    for k, val in pairs(DEFAULTS) do v[k] = type(val) == 'table' and {} or val end
    v.vel, v.coords = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 30 }
    for k, val in pairs(opts or {}) do v[k] = val end
    v.hash = hash(v.model)
    v.net = nextNet
    v.seats = {}
    F.vehicles[nextHandle] = v
    return nextHandle
end

function F.enter(handle, seat)
    F.vehicles[handle].seats[seat or -1] = F.ped
    F.pedVehicle = handle
end

function F.exitVehicle()
    local v = F.vehicles[F.pedVehicle]
    if v then for s, p in pairs(v.seats) do if p == F.ped then v.seats[s] = nil end end end
    F.pedVehicle = 0
end

function F.moveSeat(handle, seat)
    local v = F.vehicles[handle]
    for s, p in pairs(v.seats) do if p == F.ped then v.seats[s] = nil end end
    v.seats[seat] = F.ped
end

local function veh(h) return F.vehicles[h] end
local function vec(t) return { x = t.x, y = t.y, z = t.z } end

function PlayerPedId() return F.ped end
function IsPedInAnyVehicle() return F.pedVehicle ~= 0 end
function GetVehiclePedIsIn() return F.pedVehicle end
function DoesEntityExist(h) return h == F.ped or F.vehicles[h] ~= nil end
function GetPedInVehicleSeat(h, seat) local v = veh(h) return v and v.seats[seat] or 0 end
function GetVehicleMaxNumberOfPassengers(h) return veh(h).passengers end
function GetEntityModel(h) return veh(h).hash end
function GetVehicleClass(h) return veh(h).class end
local function modelFlag(flag) return function(model) for _, v in pairs(F.vehicles) do if v.hash == model then return v.kind[flag] == true end end return false end end
IsThisModelABicycle = modelFlag('bicycle')
IsThisModelAHeli = modelFlag('heli')
IsThisModelAPlane = modelFlag('plane')
IsThisModelABoat = modelFlag('boat')
IsThisModelAJetski = modelFlag('jetski')
IsThisModelABike = modelFlag('bike')
IsThisModelAQuadbike = modelFlag('quad')
function GetVehicleEstimatedMaxSpeed(h) return veh(h).estMax end
function GetEntitySpeed(h) return veh(h).speed end
function GetEntityVelocity(h) return vec(veh(h).vel) end
function GetEntityCoords(h) if h == F.ped then return vec(F.pedState.coords) end return vec(veh(h).coords) end
function GetEntitySpeedVector(h) return { x = 0, y = veh(h).speed * veh(h).forward, z = 0 } end
function GetVehicleCurrentGear(h) return veh(h).gear end
function GetIsVehicleEngineRunning(h) return veh(h).engineOn end
function GetVehicleCurrentRpm(h) return veh(h).rpm end
function GetVehicleThrottleOffset(h) return veh(h).throttle end
function GetVehicleTurboPressure(h) return veh(h).turboP end
function IsToggleModOn(h, mod) return mod == 18 and veh(h).turbo end
function GetEntityHeightAboveGround(h) return veh(h).agl end
function IsEntityDead(h) if h == F.ped then return F.pedState.dead end return veh(h).dead end
function GetVehicleEngineHealth(h) return veh(h).engineHealth end
function GetVehicleLightsState(h) local v = veh(h) return true, v.lightsOn and 1 or 0, v.high and 1 or 0 end
function SetVehicleLights(h, mode)
    local v = veh(h)
    v.lightsMode = mode
    if mode == 2 then v.lightsOn = true elseif mode == 1 then v.lightsOn, v.high = false, false end
end
function SetVehicleFullbeam(h, on) local v = veh(h) v.high = on and v.lightsOn end
function GetVehicleIndicatorLights(h) return veh(h).ind end
function SetVehicleIndicatorLights(h, index, on)
    local v = veh(h)
    local bit = index == 1 and 1 or 2
    if on then v.ind = v.ind | bit else v.ind = v.ind & (~bit) end
end
function IsPauseMenuActive() return F.ui.pause end
function IsScreenFadedOut() return F.ui.faded end
function IsPlayerSwitchInProgress() return false end
function IsHudHidden() return F.ui.hudHidden end
function IsRadarHidden() return F.ui.radarHidden end
function GetSafeZoneSize() return F.ui.safe end
function GetAspectRatio() return F.ui.aspect end
function HideHudComponentThisFrame(id) F.hiddenComponents = (F.hiddenComponents or 0) + 1 end

-- Combustible
function GetVehicleFuelLevel(h) return veh(h).fuelLevel end
function GetVehicleHandlingFloat(h, class, field) if field == 'fPetrolTankVolume' then return veh(h).tank end return 0.0 end
function DoesVehicleUseFuel(h) return veh(h).usesFuel end
function DecorExistOn(h, name) return veh(h).decors[name] ~= nil end

-- Controles
function DisableControlAction(_, control) F.disabled[control] = true end
function IsDisabledControlJustPressed(_, control) return F.disabled[control] == true and F.input.just[control] == true end
function IsControlPressed(_, control) return F.disabled[control] ~= true and F.input.pressed[control] == true end
function SetControlNormal(_, control, value) F.injected[control] = value end

-- Cinturón / expulsión
function HasEntityCollidedWithAnything(h) return veh(h).collided end
function GetOffsetFromEntityInWorldCoords(h, x, y, z) local c = veh(h).coords return { x = c.x + x, y = c.y + y, z = c.z + z } end
function SetEntityCoords(h, x, y, z)
    if h == F.ped then
        F.pedState.coords = { x = x, y = y, z = z }
        F.exitVehicle()
    end
end
function SetPedToRagdoll(h) F.pedState.ragdoll = true end
function SetEntityVelocity(h, x, y, z) F.pedState.vel = { x = x, y = y, z = z } end
function ApplyDamageToPed(h, damage) F.pedState.damage = F.pedState.damage + damage end
function GetPedConfigFlag(h, flag) return F.pedState.flags[flag] == true end
function SetPedConfigFlag(h, flag, value) F.pedState.flags[flag] = value end
function IsEntityInAir(h) return veh(h).inAir end
function GetEntityForwardVector(h) return veh(h).fwd or { x = 0, y = 1, z = 0 } end
function GetModelDimensions() return { x = -1.0, y = -2.3, z = -0.5 }, { x = 1.0, y = 2.3, z = 1.0 } end
function GetVehicleBodyHealth(h) return veh(h).body or 1000.0 end

-- Ubicación
F.place = { street = 'Vinewood Blvd', zone = 'DOWNVW', zoneLabel = 'Downtown Vinewood', heading = 0, bigmap = false }
F.pedHeading = 0
function GetStreetNameAtCoord() return F.place.street ~= '' and GetHashKey(F.place.street) or 0, 0 end
function GetStreetNameFromHashKey(hash) return F.place.street end
function GetNameOfZone() return F.place.zone end
function GetLabelText(label) if label == F.place.zone then return F.place.zoneLabel end return 'NULL' end
function GetEntityHeading(h) if h == F.ped then return F.pedHeading end return veh(h).heading or 0 end
function IsBigmapActive() return F.place.bigmap end
-- Alineación GFX (L/B): x desde el borde izquierdo de la zona segura, y desde el inferior.
F.gfxAlign = nil
function SetScriptGfxAlign(h, v) F.gfxAlign = { h, v } end
function SetScriptGfxAlignParams() end
function ResetScriptGfxAlign() F.gfxAlign = nil end
function GetScriptGfxPosition(x, y)
    local inset = (1 - F.ui.safe) / 2
    if F.gfxAlign and F.gfxAlign[1] == 76 and F.gfxAlign[2] == 66 then return inset + x, 1 - inset + y end
    return x, y
end
function GetIsTaskActive(ped, index) return index == 2 and F.pedState.exiting == true end
function IsEntityInWater(h) return veh(h).inWater end

-- Motor y nitro
function SetVehicleEngineOn(h, on) veh(h).engineOn = on end
function NetworkGetEntityIsNetworked(h) return veh(h).networked end
function VehToNet(h) return veh(h).net end
function SetVehicleCheatPowerIncrease(h, value) veh(h).power = value end
function RequestNamedPtfxAsset() end
function HasNamedPtfxAssetLoaded() return true end
function UseParticleFxAssetNextCall() end
function StartParticleFxNonLoopedOnEntity() F.particles = F.particles + 1 end
function GetEntityBoneIndexByName(h, bone) return bone == 'exhaust' and 7 or -1 end
function GetWorldPositionOfEntityBone(h) return vec(veh(h).coords) end
function GetOffsetFromEntityGivenWorldCoords() return { x = 0, y = -2, z = 0.3 } end

-- Servidor
function NetworkGetEntityFromNetworkId(net)
    for h, v in pairs(F.vehicles) do if v.net == net then return h end end
    return 0
end
function GetEntityType(h) return F.vehicles[h] and 2 or 1 end
function GetVehicleNumberPlateText(h) return veh(h).plate end
function GetVehicleType(h) return veh(h).type end
F.playerPeds = {}
function GetPlayerPed(src) return F.playerPeds[src] or 0 end
function GetPlayerName(src) return 'Jugador' .. tostring(src) end
F.aces = {}
function IsPlayerAceAllowed(src, ace) return F.aces[tostring(src) .. ':' .. ace] == true end
F.files = {}
function SaveResourceFile(_, name, data) F.files[name] = data return true end
function LoadResourceFile(_, name)
    if F.files[name] ~= nil then return F.files[name] end
    if name:match('^locales/') then return FD_READ(R .. '/' .. name) end
end

------------------------------------------------------------------------------
-- Carga del recurso
------------------------------------------------------------------------------
function F.load(files)
    for _, file in ipairs(files) do dofile(R .. '/' .. file) end
end

F.SHARED = {
    'config.lua', 'shared/utils.lua', 'shared/locale.lua',
    'shared/profiles.lua', 'shared/crash.lua', 'shared/settings.lua', 'shared/admin.lua', 'shared/geo.lua',
}
F.CLIENT = {
    'bridge/client/framework.lua', 'bridge/client/fuel.lua', 'client/core.lua', 'client/nui.lua', 'client/admin.lua', 'client/perf.lua',
    'client/settings.lua', 'client/telemetry.lua', 'client/location.lua', 'client/seatbelt.lua', 'client/lights.lua', 'client/cruise.lua',
    'client/engine.lua', 'client/nitro.lua', 'client/keys.lua', 'client/main.lua',
}
F.SERVER = { 'bridge/server/framework.lua', 'server/admin.lua', 'server/nitro_store.lua', 'server/nitro.lua', 'server/main.lua' }

------------------------------------------------------------------------------
-- Aserciones
------------------------------------------------------------------------------
F.passed, F.failed = 0, 0
function F.ok(cond, name)
    if cond then
        F.passed = F.passed + 1
        realPrint('  ok   ' .. name)
    else
        F.failed = F.failed + 1
        realPrint('  FAIL ' .. name)
    end
end
function F.eq(a, b, name)
    F.ok(a == b, name .. (a == b and '' or (' (obtenido ' .. tostring(a) .. ', esperado ' .. tostring(b) .. ')')))
end
function F.near(a, b, eps, name)
    local good = type(a) == 'number' and math.abs(a - b) <= eps
    F.ok(good, name .. (good and '' or (' (obtenido ' .. tostring(a) .. ', esperado ' .. tostring(b) .. ')')))
end
function F.section(title) realPrint('\n' .. title) end
function F.finish()
    realPrint(('\n%d correctas, %d fallidas'):format(F.passed, F.failed))
    if F.failed > 0 then error('pruebas fallidas') end
end

return F
