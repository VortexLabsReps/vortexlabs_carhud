-- Telemetría real del vehículo y visibilidad del HUD.
-- · Rápida (Config.Rates.fast): velocidad, RPM, marcha, pedal, altitud.
-- · Lenta (Config.Rates.slow): combustible, motor, luces, cinturón, crucero, nitro.
-- Solo se envía a la NUI lo que cambia por encima de un umbral; la NUI interpola.
-- Nada de esto se transmite al servidor.
local Util = CarHud.Util
local Profiles = CarHud.Profiles
local NUI = CarHud.NUI
local S = CarHud.State

local Telemetry = { token = 0 }
local lastFast, lastSlow = {}, {}
local slowNow = false
local hasThrottleOffset = type(GetVehicleThrottleOffset) == 'function'
local NO_DATA = -1 -- la NUI lo interpreta como "sin dato" (JSON no transporta nil)

local function put(cache, message, key, value, epsilon)
    local old = cache[key]
    if old == nil or (epsilon and math.abs(old - value) > epsilon) or (not epsilon and old ~= value) then
        cache[key] = value
        message[key] = value
        return true
    end
    return false
end

------------------------------------------------------------------------------
-- Visibilidad: única fuente para todo el HUD (velocímetro, nitro, fila inferior
-- y ubicación). Se decide aquí y se envía en un solo mensaje.
------------------------------------------------------------------------------
local EXIT_VEHICLE_TASK = 2 -- CTaskExitVehicle (eTaskTypeIndex)

local function shouldShow()
    local profile = S.profile
    if S.veh == 0 or not profile or not profile.hud then return false end
    -- Al empezar a bajar se oculta todo a la vez, sin esperar a estar fuera.
    if GetVehiclePedIsIn(S.ped, false) ~= S.veh or GetIsTaskActive(S.ped, EXIT_VEHICLE_TASK) then return false end
    if not S.isDriver and not Config.Hud.showForPassengers then return false end
    if IsPauseMenuActive() or IsScreenFadedOut() or IsPlayerSwitchInProgress() then return false end
    if Config.Hud.hideWhenHudHidden and IsHudHidden() then return false end
    if Config.Hud.hideWhenRadarHidden and IsRadarHidden() then return false end
    if IsEntityDead(S.ped) then return false end
    if next(S.hiddenBy) then return false end
    return CarHud.Framework.ready()
end

local sendSafeZone

-- La ubicación depende del HUD (nunca visible sin él) y además del minimapa.
local function locationAllowed()
    return CarHud.Location ~= nil and CarHud.Location.allowed()
end

-- Mensaje de visibilidad: HUD y ubicación juntos; si la ubicación aparece, lleva
-- ya su calle, zona y rumbo para que no se vea un dato del vehículo anterior.
local function visibilityMessage()
    local msg = { t = 'visible', v = S.visible == true, loc = S.locVisible == true }
    if msg.loc then CarHud.Location.snapshot(msg) end
    return msg
end

local function setVisible(visible, loc)
    loc = visible and loc or false
    if S.visible == visible and S.locVisible == loc then return end
    local changed = S.visible ~= visible
    if changed then
        S.visible = visible
        lastFast, lastSlow = {}, {}
        slowNow = visible
    end
    S.locVisible = loc
    if loc then sendSafeZone() end -- el ancla del minimapa llega antes que la orden
    NUI.send(visibilityMessage())
    if changed then CarHud.emit('visibility', visible) end
end

------------------------------------------------------------------------------
-- Zona segura y minimapa (normalizado 0–1), para no solaparlo.
------------------------------------------------------------------------------
local lastSafe = nil

-- Rectángulo del minimapa (fracciones de pantalla) con el propio sistema de
-- alineación de GTA: aplica la zona segura y la relación de aspecto igual que
-- el juego. Las medidas son las del componente 'minimap' de frontend.xml
-- (Config.Location.minimap, por si el servidor lo cambia con SetMinimapComponentPosition).
local function minimapRect()
    local m = Config.Location.minimap
    local scaleX = (16 / 9) / GetAspectRatio(false) -- el tamaño se define en espacio 16:9
    SetScriptGfxAlign(76, 66) -- 'L', 'B'
    SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
    local x1, y1 = GetScriptGfxPosition(m.posX, m.posY - m.sizeY)
    local x2, y2 = GetScriptGfxPosition(m.posX + m.sizeX * scaleX, m.posY)
    ResetScriptGfxAlign()
    return { l = math.max(x1, 0.0), t = y1, r = x2, b = y2 }
end
Telemetry.minimapRect = minimapRect

function sendSafeZone()
    local safe = GetSafeZoneSize()
    local minimap = false
    if not IsRadarHidden() then minimap = minimapRect() end
    local key = ('%.3f|%s'):format(safe, minimap and ('%.4f,%.4f,%.4f,%.4f'):format(minimap.l, minimap.t, minimap.r, minimap.b) or '-')
    if key == lastSafe then return end
    lastSafe = key
    NUI.send({ t = 'safe', safe = safe, mm = minimap, gap = Config.Location.gap })
end
Telemetry.sendSafeZone = sendSafeZone

------------------------------------------------------------------------------
-- Lecturas
------------------------------------------------------------------------------
local function horizontalSpeed(vehicle)
    local v = GetEntityVelocity(vehicle)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

local function readFast(vehicle, profile, send)
    local speed = profile.aircraft and horizontalSpeed(vehicle) or GetEntitySpeed(vehicle)
    if not send then return speed end

    local msg, changed = { t = 'f' }, false
    changed = put(lastFast, msg, 's', Util.round(speed, 2), 0.05) or changed

    local gear = nil
    if profile.gear then
        gear = GetVehicleCurrentGear(vehicle)
        changed = put(lastFast, msg, 'g', gear) or changed
    end
    if profile.rpm then
        local rpm = GetIsVehicleEngineRunning(vehicle) and GetVehicleCurrentRpm(vehicle) or 0.0
        changed = put(lastFast, msg, 'r', Util.round(Util.clamp(rpm, 0, 1), 3), 0.005) or changed
    end
    if profile.throttle then
        local offset = hasThrottleOffset and GetVehicleThrottleOffset(vehicle) or 0.0
        -- En embarcaciones el empuje atrás también es potencia aplicada.
        local pedal = Profiles.pedal(offset, profile.category == 'boat' and 0 or (gear or 1))
        changed = put(lastFast, msg, 'p', Util.round(pedal, 3), 0.01) or changed
    end
    if profile.aircraft then
        if profile.altitudeMsl then
            changed = put(lastFast, msg, 'm', Util.round(GetEntityCoords(vehicle).z), 0.5) or changed
        end
        if profile.altitudeAgl then
            changed = put(lastFast, msg, 'a', Util.round(GetEntityHeightAboveGround(vehicle)), 0.5) or changed
        end
        if profile.verticalSpeed then
            changed = put(lastFast, msg, 'v', Util.round(GetEntityVelocity(vehicle).z, 2), 0.05) or changed
        end
    end
    if changed then NUI.send(msg) end
    return speed
end

local function readSlow(vehicle, profile, speed, send)
    local speedKmh = speed * Util.KMH
    local dead = IsEntityDead(vehicle)
    local belt, beltWarn = CarHud.Seatbelt.telltale(speedKmh, send)

    if not send then return end

    local msg, changed = { t = 's' }, false

    if profile.fuel then
        local fuel = CarHud.Fuel.read(vehicle)
        if fuel == nil then fuel = NO_DATA elseif fuel ~= false then fuel = Util.round(fuel, 1) end
        changed = put(lastSlow, msg, 'fuel', fuel) or changed
    end
    if profile.engine then
        local health = dead and 0 or (Util.engineHealthPct(GetVehicleEngineHealth(vehicle)) or 0)
        changed = put(lastSlow, msg, 'eng', Util.round(health, 1)) or changed
    end
    changed = put(lastSlow, msg, 'run', GetIsVehicleEngineRunning(vehicle) and not dead) or changed

    local nitro = CarHud.Nitro.display(vehicle)
    local nitroKey = nitro and ('%.1f|%.1f|%s'):format(nitro.amt, nitro.cap, tostring(nitro.on)) or 'none'
    if lastSlow.nitroKey ~= nitroKey then
        lastSlow.nitroKey = nitroKey
        msg.nos = nitro
        changed = true
    end

    changed = put(lastSlow, msg, 'beltWarn', beltWarn == true) or changed

    local tt, ttChanged = {}, false
    if belt then ttChanged = put(lastSlow, tt, 'belt', belt) or ttChanged end
    if profile.show.lights then ttChanged = put(lastSlow, tt, 'lights', CarHud.Lights.state(vehicle)) or ttChanged end
    if profile.show.indicators then ttChanged = put(lastSlow, tt, 'ind', GetVehicleIndicatorLights(vehicle)) or ttChanged end
    if profile.cruise then ttChanged = put(lastSlow, tt, 'cruise', Util.round(CarHud.Cruise.target, 2)) or ttChanged end
    if ttChanged then
        msg.tt = tt
        changed = true
    end

    if changed then NUI.send(msg) end
end

------------------------------------------------------------------------------
-- Perfil para la NUI
------------------------------------------------------------------------------
function Telemetry.profileMessage(profile)
    return {
        t = 'profile',
        profile = {
            category = profile.category,
            compact = profile.compact == true,
            aircraft = profile.aircraft or false,
            gear = profile.gear, rpm = profile.rpm, throttle = profile.throttle,
            fuel = profile.fuel, engine = profile.engine, nitro = profile.nitro,
            scaleKmh = S.scaleKmh,
            redline = profile.redline or 8000,
            telltales = {
                belt = CarHud.Seatbelt.applies(),
                lights = profile.show.lights,
                cruise = profile.cruise,
                indicators = profile.show.indicators,
            },
        },
    }
end

-- Fuerza una lectura lenta inmediata (tras pulsar una tecla, por ejemplo).
function Telemetry.poke()
    slowNow = true
end

------------------------------------------------------------------------------
-- Bucle: uno por vehículo; termina solo al salir o cambiar de vehículo.
------------------------------------------------------------------------------
function Telemetry.start(vehicle)
    Telemetry.token = Telemetry.token + 1
    local token = Telemetry.token
    lastFast, lastSlow, lastSafe = {}, {}, nil
    NUI.send(Telemetry.profileMessage(S.profile))

    CreateThread(function()
        -- Cadencias por tiempo de juego, no por vueltas: Wait() se redondea al
        -- fotograma, así que contar vueltas alargaría los intervalos.
        local nextSlow, nextSafe = 0, 0
        while Telemetry.token == token and S.veh == vehicle do
            local started = CarHud.Perf.begin()
            local now = GetGameTimer()
            local profile = S.profile
            local visible = shouldShow()
            setVisible(visible, visible and locationAllowed())

            local speed = readFast(vehicle, profile, visible)
            if now >= nextSlow or slowNow then
                nextSlow, slowNow = now + Config.Rates.slow, false
                readSlow(vehicle, profile, speed, visible)
            end
            if visible and now >= nextSafe then
                nextSafe = now + 2000
                sendSafeZone()
            end
            CarHud.Perf.finish(started)
            Wait(visible and Config.Rates.fast or Config.Rates.slow)
        end
    end)
end

function Telemetry.stop()
    Telemetry.token = Telemetry.token + 1
    setVisible(false)
end

-- Reenvía el perfil (p. ej. al cambiar el modo de cinturón).
function Telemetry.refreshProfile()
    if S.veh ~= 0 and S.profile then
        NUI.send(Telemetry.profileMessage(S.profile))
        lastSlow = {}
        slowNow = true
    end
end

-- Cambios de administración: el perfil ya se recalculó; se reenvía a la NUI.
CarHud.on('config', function() Telemetry.refreshProfile() end)

CarHud.on('nuiReady', function()
    lastFast, lastSlow, lastSafe = {}, {}, nil
    if S.veh ~= 0 and S.profile then NUI.send(Telemetry.profileMessage(S.profile)) end
    NUI.send(visibilityMessage())
end)

CarHud.Telemetry = Telemetry
