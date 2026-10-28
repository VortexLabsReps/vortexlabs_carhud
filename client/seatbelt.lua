-- Cinturón. Modo 'own': mecánica propia (tecla, sonidos, aviso, bloqueo de la
-- tecla de salida y expulsión opcional). Modo 'external': solo refleja el estado
-- de otro recurso. Modo 'off': sin cinturón.
-- El bloqueo solo desactiva la tecla de salir (INPUT_VEH_EXIT); las salidas
-- forzadas por otros scripts, la muerte o el arrastre no se ven afectadas.
local Util = CarHud.Util
local NUI = CarHud.NUI
local S = CarHud.State
local cfg = Config.Seatbelt
local Admin = CarHud.Admin

local Seatbelt = { mode = 'off', on = false }
local EXIT_CONTROL = 75          -- INPUT_VEH_EXIT
local FLY_THROUGH_FLAG = 32      -- CPED_CONFIG_FLAG_WillFlyThroughWindscreen
local savedFlag = nil
local lastWarn = nil            -- último aviso sonoro (nil = aún ninguno)
local lastExitNotice = 0
local crash = CarHud.Crash.new(cfg.ejection)
local ejectEligible = false      -- ¿se permite la expulsión en el vehículo actual?
local lastEject = nil            -- protección entre expulsiones

local function started(resource)
    return GetResourceState(resource) == 'started'
end

function Seatbelt.resolveMode()
    if not Config.Features.seatbelt or cfg.mode == 'off' then return 'off' end
    if cfg.mode == 'auto' then
        for _, resource in ipairs(cfg.knownResources or {}) do
            if started(resource) then return 'external' end
        end
        return 'own'
    end
    if cfg.mode == 'external' then return 'external' end
    return 'own'
end

-- ¿Este vehículo y este modo tienen cinturón?
function Seatbelt.applies()
    return Seatbelt.mode ~= 'off' and S.veh ~= 0 and S.profile ~= nil and S.profile.seatbelt == true
end

-- Expulsión: mecánica propia, activada y permitida para esta categoría/modelo
-- (por defecto solo automóviles; nunca bicicletas). En categorías sin cinturón
-- (motos, por ejemplo) el ocupante cuenta siempre como desabrochado.
local function computeEligibility()
    local profile = S.profile
    ejectEligible = Seatbelt.mode == 'own' and cfg.ejection.enabled == true and S.veh ~= 0
        and profile ~= nil and profile.hud == true
        and Admin.ejectionAllowed(profile.category, GetEntityModel(S.veh), GetHashKey)
end

local function protectedByBelt()
    return Seatbelt.applies() and Seatbelt.on
end

function Seatbelt.isOn()
    if Seatbelt.mode == 'external' then
        local state = LocalPlayer.state
        local belt, harness = state[cfg.external.stateKey], state[cfg.external.harnessKey]
        if belt ~= nil or harness ~= nil then return belt == true or harness == true end
    end
    return Seatbelt.on
end

------------------------------------------------------------------------------
-- Mecánica propia
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Diagnóstico (/carhudcrash, solo con permiso de administración)
------------------------------------------------------------------------------
local Diag = { enabled = false, lastSend = 0, lastLog = 0, decision = nil }
Seatbelt.Diag = Diag

local REASONS_LOGGED = { impact = true, cooldown = true, belted = true, not_allowed = true, dead = true,
    ratio = true, min_speed = true, airborne = true, teleport = true, no_collision = true }

local function heading(v)
    local h = math.deg(math.atan(v.x, v.y))
    if h < 0 then h = h + 360 end
    return h
end

-- reason: motivo final (puede sustituir al del detector: cinturón, protección…)
function Diag.report(result, reason)
    if not Diag.enabled or not result then return end
    local now = GetGameTimer()
    local ej = cfg.ejection
    -- Una decisión es relevante si hubo un cambio apreciable (≥ mitad del umbral) o expulsión.
    if result.dv >= ej.minDelta * 0.5 and REASONS_LOGGED[reason] then
        Diag.decision = { reason = reason, dv = result.dv, impact = result.impact, evidence = result.evidence,
            collisionAge = result.collisionAge < 100000 and result.collisionAge or -1, t = now }
        if now - Diag.lastLog > 300 or reason == 'impact' then
            Diag.lastLog = now
            print('[vortexlabs_carhud] ' .. CarHud.T('crash_log', reason, result.dv, result.impact, result.ratio,
                result.collisionAge < 100000 and CarHud.T('crash_ago', result.collisionAge) or CarHud.T('crash_none'),
                math.max(result.bodyDrop or 0, 0)))
        end
    end
    if now - Diag.lastSend < 100 and reason ~= 'impact' then return end
    Diag.lastSend = now
    local samples = {}
    for i = math.max(1, #crash.samples - 7), #crash.samples do
        local smp = crash.samples[i]
        samples[#samples + 1] = { dt = now - smp.t, kmh = math.floor(math.sqrt(smp.vel.x ^ 2 + smp.vel.y ^ 2) * Util.KMH + 0.5), hdg = math.floor(heading(smp.vel) + 0.5) }
    end
    NUI.send({ t = 'crashDiag', data = {
        speed = math.sqrt(result.now.vel.x ^ 2 + result.now.vel.y ^ 2) * Util.KMH,
        heading = heading(result.now.vel),
        samples = samples, window = ej.window,
        dv = result.dv, minDelta = ej.minDelta,
        ratio = result.ratio, minRatio = ej.minRatio,
        impact = result.impact, minSpeed = ej.minSpeed,
        collisionAge = result.collisionAge < 100000 and result.collisionAge or -1,
        bodyDrop = result.bodyDrop or 0, evidence = result.evidence,
        belted = protectedByBelt(), allowed = ejectEligible, enabled = ej.enabled,
        reason = reason, decision = Diag.decision,
    } })
end

function Diag.set(enabled)
    Diag.enabled = enabled == true
    Diag.decision = nil
    NUI.send({ t = 'crashDiag', data = Diag.enabled and {} or false })
end

RegisterNetEvent('vortexlabs_carhud:crashdiag', function(allowed)
    if allowed == true then Diag.set(not Diag.enabled) end
    if Seatbelt.refresh then Seatbelt.refresh() end
end)

------------------------------------------------------------------------------
-- Expulsión: el impulso se calcula aparte de la detección (Crash.ejection) y
-- el personaje aparece fuera del vehículo en la dirección de salida.
------------------------------------------------------------------------------
local function exitPoint(vehicle, dir)
    local c = GetEntityCoords(vehicle)
    local fwd = GetEntityForwardVector(vehicle)
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local halfLen, halfWid = math.max(math.abs(min.y), math.abs(max.y)), math.max(math.abs(min.x), math.abs(max.x))
    -- Componentes de la dirección en los ejes del vehículo (adelante / derecha).
    local along = dir.x * fwd.x + dir.y * fwd.y
    local side = dir.x * fwd.y - dir.y * fwd.x
    local reach = math.min(halfLen / math.max(math.abs(along), 0.01), halfWid / math.max(math.abs(side), 0.01)) + 0.6
    return { x = c.x + dir.x * reach, y = c.y + dir.y * reach, z = c.z + 1.0 }
end

local function eject(vehicle, result)
    local ej = cfg.ejection
    local now = GetGameTimer()
    if lastEject and now - lastEject < ej.cooldown then
        Diag.report(result, 'cooldown')
        return
    end
    lastEject = now
    Diag.report(result, 'impact')
    local ped = S.ped
    local out = CarHud.Crash.ejection(result, ej)
    local pos = exitPoint(vehicle, out.dir)
    CreateThread(function()
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        Wait(1)
        SetPedToRagdoll(ped, ej.ragdoll, ej.ragdoll, 0, false, false, false)
        SetEntityVelocity(ped, out.vel.x, out.vel.y, out.vel.z)
        if ej.damageEnabled and ej.damage > 0 then ApplyDamageToPed(ped, ej.damage, false) end
    end)
end

local function frameTask()
    local vehicle = S.veh
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local belted = protectedByBelt()
    if belted then
        if cfg.lockExit then
            DisableControlAction(0, EXIT_CONTROL, true)
            if IsDisabledControlJustPressed(0, EXIT_CONTROL) then
                local now = GetGameTimer()
                if now - lastExitNotice > 1500 then
                    lastExitNotice = now
                    CarHud.notify('notice.exitLocked', 'warn')
                end
            end
        end
        if not Diag.enabled then return end
    end

    local active = ejectEligible and cfg.ejection.enabled
    if not active and not Diag.enabled then return end
    -- Se muestrea siempre (también parado): un golpe recibido puede llegar sin movimiento previo.
    local result = crash:push({
        t = GetGameTimer(),
        vel = GetEntityVelocity(vehicle),
        pos = GetEntityCoords(vehicle),
        collided = HasEntityCollidedWithAnything(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        inAir = IsEntityInAir(vehicle),
    })
    if not result.hit then return Diag.report(result, result.reason) end
    if belted then return Diag.report(result, 'belted') end
    if not active then return Diag.report(result, 'not_allowed') end
    if IsEntityDead(S.ped) then return Diag.report(result, 'dead') end
    eject(vehicle, result)
end

local function refreshFrameTask()
    local needs = (Seatbelt.mode == 'own'
        and ((protectedByBelt() and cfg.lockExit) or (not protectedByBelt() and ejectEligible)))
        or (Diag.enabled and S.veh ~= 0)
    if needs then CarHud.Frame.set('seatbelt', frameTask) else CarHud.Frame.clear('seatbelt') end
end

local function setOn(value, silent)
    Seatbelt.on = value
    if Seatbelt.mode == 'own' then
        LocalPlayer.state:set('seatbelt', value, true)
        if not silent then NUI.send({ t = 'sound', name = value and 'belt_on' or 'belt_off' }) end
    end
    crash:reset()
    refreshFrameTask()
    CarHud.Telemetry.poke()
end

function Seatbelt.refresh()
    refreshFrameTask()
end

function Seatbelt.toggle()
    if Seatbelt.mode ~= 'own' or not Seatbelt.applies() or IsPauseMenuActive() then return end
    if IsEntityDead(S.ped) then return end
    setOn(not Seatbelt.on)
end

-- Estado del testigo y aviso. Devuelve estado ('on'|'off'|'warn') y si hay que avisar.
function Seatbelt.telltale(speedKmh, canSound)
    if not Seatbelt.applies() then return nil, false end
    if Seatbelt.isOn() then return 'on', false end
    if speedKmh >= cfg.warnSpeed then
        if Seatbelt.mode == 'own' and canSound and cfg.warnSound then
            local now = GetGameTimer()
            if not lastWarn or now - lastWarn >= cfg.warnInterval then
                lastWarn = now
                NUI.send({ t = 'sound', name = 'belt_warn' })
            end
        end
        return 'warn', true
    end
    lastWarn = nil
    return 'off', false
end

------------------------------------------------------------------------------
-- Ciclo de vida: el estado se restablece al entrar, salir y reiniciar.
------------------------------------------------------------------------------
local function restoreFlag()
    if savedFlag ~= nil and DoesEntityExist(S.ped) then
        SetPedConfigFlag(S.ped, FLY_THROUGH_FLAG, savedFlag)
    end
    savedFlag = nil
end

-- Solo esta mecánica decide la expulsión mientras se está dentro de un vehículo
-- con cinturón propio o con expulsión permitida.
local function takeFlag()
    if savedFlag == nil and Seatbelt.mode == 'own' and (Seatbelt.applies() or ejectEligible) then
        savedFlag = GetPedConfigFlag(S.ped, FLY_THROUGH_FLAG, true)
        SetPedConfigFlag(S.ped, FLY_THROUGH_FLAG, false)
    end
end

CarHud.on('enter', function()
    Seatbelt.on = false
    lastWarn = nil
    computeEligibility()
    if Seatbelt.mode == 'own' and Seatbelt.applies() then LocalPlayer.state:set('seatbelt', false, true) end
    takeFlag()
    crash:reset()
    refreshFrameTask()
end)

CarHud.on('exit', function()
    if Seatbelt.on and Seatbelt.mode == 'own' then LocalPlayer.state:set('seatbelt', false, true) end
    Seatbelt.on = false
    restoreFlag()
    CarHud.Frame.clear('seatbelt')
end)

CarHud.on('stop', function()
    if Seatbelt.mode == 'own' then LocalPlayer.state:set('seatbelt', false, true) end
    restoreFlag()
end)

-- Respaldo para cinturones externos que solo emiten un evento de alternancia.
AddEventHandler(cfg.external.toggleEvent, function()
    if Seatbelt.mode == 'external' then
        Seatbelt.on = not Seatbelt.on
        CarHud.Telemetry.poke()
    end
end)

local function updateMode()
    local mode = Seatbelt.resolveMode()
    if mode == Seatbelt.mode then return end
    if Seatbelt.mode == 'own' then
        if Seatbelt.on then LocalPlayer.state:set('seatbelt', false, true) end
        restoreFlag()
    end
    Seatbelt.mode = mode
    Seatbelt.on = false
    refreshFrameTask()
    if CarHud.Keys then CarHud.Keys.ensureSeatbelt() end
    CarHud.Telemetry.refreshProfile()
end

AddEventHandler('onClientResourceStart', function(resource)
    for _, name in ipairs(cfg.knownResources or {}) do
        if name == resource then updateMode() return end
    end
end)
AddEventHandler('onClientResourceStop', function(resource)
    for _, name in ipairs(cfg.knownResources or {}) do
        if name == resource then SetTimeout(0, updateMode) return end
    end
end)

-- Cambios del menú de administración: se recalcula todo en caliente.
CarHud.on('config', function()
    updateMode()
    computeEligibility()
    if S.veh ~= 0 then
        if not Seatbelt.applies() and Seatbelt.on then Seatbelt.on = false end
        takeFlag()
    end
    refreshFrameTask()
end)

Seatbelt.mode = Seatbelt.resolveMode()
CarHud.Seatbelt = Seatbelt
