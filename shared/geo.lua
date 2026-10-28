-- Ubicación: rumbo y nombres de lugar. Puro (sin natives) para probarlo fuera del juego.
local Util = CarHud.Util
local Geo = {}

Geo.SECTORS = 8 -- N, NE, E, SE, S, SO/SW, O/W, NO/NW (la NUI pone las letras según el idioma)

-- GTA mide el rumbo en sentido antihorario (0 norte, 90 oeste, como en
-- qbx.getCardinalDirection). La brújula usa sentido horario: 90 = este.
function Geo.bearing(heading)
    return (360 - (Util.number(heading) or 0)) % 360
end

local function angularDiff(a, b)
    local d = math.abs(a - b) % 360
    return d > 180 and 360 - d or d
end
Geo.angularDiff = angularDiff

-- Sector 0..7 del rumbo. Con histéresis: se mantiene el sector actual hasta
-- salir de él más de `hysteresis` grados, para que cerca del límite entre dos
-- puntos cardinales no parpadee.
function Geo.sector(bearing, current, hysteresis)
    local width = 360 / Geo.SECTORS
    local raw = math.floor((bearing + width / 2) / width) % Geo.SECTORS
    if current == nil or current == raw then return raw end
    if angularDiff(bearing, current * width) <= width / 2 + (hysteresis or 8) then return current end
    return raw
end

local function clean(text)
    if type(text) ~= 'string' then return '' end
    text = Util.trim(text)
    if text == 'NULL' or text:find('^~') then return '' end
    return text
end

-- Texto principal y secundario. Sin calle (mar, campo, monte) se muestra la zona
-- como principal y nada debajo: nunca se conserva una calle anterior.
function Geo.place(street, zone)
    street, zone = clean(street), clean(zone)
    if street == '' then
        return zone, ''
    end
    return street, zone
end

CarHud.Geo = Geo
