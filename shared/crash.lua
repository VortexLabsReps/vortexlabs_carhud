-- Detección de accidentes para la expulsión sin cinturón (puro: se prueba fuera
-- del juego). Trabaja con el VECTOR de velocidad horizontal, no con la rapidez:
-- así detecta impactos frontales, traseros, laterales y diagonales, choques
-- circulando marcha atrás y golpes recibidos de otro vehículo (aunque esté parado).
--
-- Cada fotograma se añade una muestra { t, vel, pos, collided, body, inAir }.
-- Δv = mayor |v_ahora − v_i| (plano horizontal) entre las muestras de la ventana.
-- Hay accidente si, a la vez:
--   · Δv ≥ minDelta (km/h)                      → cambio brusco de velocidad o dirección
--   · Δv ≥ minRatio × velocidad de referencia   → evita frenadas y curvas rápidas
--   · velocidad del impacto ≥ minSpeed (km/h)    → la mayor entre la del vehículo y Δv
--   · evidencia de colisión: el juego registró un choque en la ventana o la
--     carrocería perdió salud
-- y se descarta si el vehículo estuvo en el aire (saltos/aterrizajes) o se
-- teletransportó. El impulso de expulsión se calcula aparte (ejectVelocity).
local Crash = {}
Crash.__index = Crash

local KMH = 3.6
local AIR_GRACE = 400        -- ms tras tocar suelo en los que se ignoran cambios (aterrizajes)
local TELEPORT_GRACE = 1000  -- ms tras un salto de posición
local BODY_EVIDENCE = 5      -- puntos de salud de carrocería perdidos que cuentan como golpe

local function hlen(x, y) return math.sqrt(x * x + y * y) end

function Crash.new(cfg)
    return setmetatable({ cfg = cfg, samples = {}, lastAir = -math.huge, lastCollision = -math.huge, lastTeleport = -math.huge, last = nil }, Crash)
end

function Crash:reset()
    self.samples = {}
    self.lastAir, self.lastCollision, self.lastTeleport = -math.huge, -math.huge, -math.huge
end

-- s = { t, vel = {x,y,z}, pos = {x,y,z}|nil, collided = bool, body = number|nil, inAir = bool }
-- Devuelve una evaluación: { hit, reason, dv, impact, peak, ratio, evidence, pre, now, dvVec }
function Crash:push(s)
    local cfg, samples = self.cfg, self.samples
    local prev = samples[#samples]

    if s.inAir then self.lastAir = s.t end
    if s.collided then self.lastCollision = s.t end
    -- Teletransporte: desplazamiento imposible entre dos muestras seguidas.
    if prev and prev.pos and s.pos then
        local dt = math.max((s.t - prev.t) / 1000, 0.001)
        local moved = math.sqrt((s.pos.x - prev.pos.x) ^ 2 + (s.pos.y - prev.pos.y) ^ 2 + (s.pos.z - prev.pos.z) ^ 2)
        local expected = math.max(hlen(s.vel.x, s.vel.y), hlen(prev.vel.x, prev.vel.y)) * dt
        if moved > expected * 3 + 4 then
            self.lastTeleport = s.t
            self.samples = {}
            samples = self.samples
        end
    end

    samples[#samples + 1] = s
    local cutoff = s.t - cfg.window
    while samples[1] and samples[1].t < cutoff do table.remove(samples, 1) end

    -- Variación del vector de velocidad horizontal respecto a cada muestra reciente.
    local best, dv, dx, dy, peak = nil, 0, 0, 0, 0
    for i = 1, #samples do
        local o = samples[i]
        local sp = hlen(o.vel.x, o.vel.y)
        if sp > peak then peak = sp end
        if o ~= s then
            local ex, ey = s.vel.x - o.vel.x, s.vel.y - o.vel.y
            local d = hlen(ex, ey)
            if d > dv then best, dv, dx, dy = o, d, ex, ey end
        end
    end
    local dvKmh, peakKmh = dv * KMH, peak * KMH
    local impact = math.max(peakKmh, dvKmh)
    local ratio = dvKmh / math.max(peakKmh, 1)
    local bodyDrop = (best and best.body and s.body) and (best.body - s.body) or 0
    local collisionAge = s.t - self.lastCollision
    local evidence = collisionAge <= cfg.window or bodyDrop >= BODY_EVIDENCE

    local result = {
        hit = false, dv = dvKmh, impact = impact, peak = peakKmh, ratio = ratio,
        evidence = evidence, collisionAge = collisionAge, bodyDrop = bodyDrop,
        pre = best, now = s, dvVec = { x = dx, y = dy },
    }
    if s.t - self.lastTeleport < TELEPORT_GRACE then
        result.reason = 'teleport'
    elseif dvKmh < cfg.minDelta then
        result.reason = 'below_delta'
    elseif ratio < cfg.minRatio then
        result.reason = 'ratio'
    elseif impact < cfg.minSpeed then
        result.reason = 'min_speed'
    elseif s.t - self.lastAir < cfg.window + AIR_GRACE then
        result.reason = 'airborne'
    elseif not evidence then
        result.reason = 'no_collision'
    else
        result.hit = true
        result.reason = 'impact'
        self.samples = {}
    end
    self.last = result
    return result
end

-- IMPULSO de la expulsión (independiente de la detección). El ocupante sigue
-- con la inercia previa: sale en sentido contrario al cambio de velocidad que
-- sufrió el vehículo (−Δv). Frontal → hacia delante; marcha atrás contra un
-- muro → hacia atrás; golpe lateral → hacia el lado del que vino el golpe.
-- Velocidad del mundo = velocidad actual del vehículo − Δv × fuerza horizontal,
-- más el impulso vertical configurado.
function Crash.ejection(result, cfg)
    local h = cfg.horizontalForce or 1.0
    local now, d = result.now.vel, result.dvVec
    local len = hlen(d.x, d.y)
    local dir = len > 0.001 and { x = -d.x / len, y = -d.y / len } or { x = 0, y = 0 }
    return {
        dir = dir,
        vel = {
            x = now.x - d.x * h,
            y = now.y - d.y * h,
            z = math.max(now.z, 0) + (cfg.verticalForce or 0),
        },
    }
end

CarHud.Crash = Crash
