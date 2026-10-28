-- Utilidades compartidas. Sin natives: también se cargan en el banco de pruebas.
CarHud = CarHud or {}

local Util = {}

Util.KMH = 3.6          -- m/s → km/h
Util.MPH = 2.236936     -- m/s → mph
Util.FEET = 3.28084     -- m → ft

function Util.clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

function Util.round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

-- Número finito o nil (descarta NaN, infinitos y no numéricos).
function Util.number(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

-- Salud del motor (GetVehicleEngineHealth) a porcentaje. Rango oficial del juego:
-- -4000 a 1000 (1000 perfecto · 300 humea y pierde potencia · 0 o menos arde y se
-- destruye). Por eso 1000 → 100 % y cualquier valor ≤ 0 → 0 % (motor averiado).
function Util.engineHealthPct(health)
    health = Util.number(health)
    if not health then return nil end
    return Util.clamp(health, 0, 1000) / 10
end

function Util.trim(text)
    return (tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Util.normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = Util.trim(plate):upper()
    if plate == '' then return nil end
    return plate
end

function Util.isHexColor(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

-- Avisos de error que pueden repetirse (p. ej. dentro de un bucle): como mucho
-- uno por clave cada 60 s, para que la consola siga siendo legible.
local warned = {}
function Util.warn(key, text)
    local now = GetGameTimer and GetGameTimer() or 0
    if warned[key] and now - warned[key] < 60000 then return end
    warned[key] = now
    print(('[vortexlabs_carhud] %s'):format(text))
end

function Util.debug(...)
    if Config and Config.Debug then
        print(('[vortexlabs_carhud] %s'):format(table.concat({ ... }, ' ')))
    end
end

CarHud.Util = Util
