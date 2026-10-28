-- Ajustes administrables en el juego (/carhudadmin). Cada campo apunta a una
-- ruta de Config, con tipo y límites. El servidor valida con validate() todo lo
-- que llega del cliente; el cliente usa el mismo esquema para construir el menú.
-- Los permisos de llaves (Config.Engine.authorize) y la matriz de categorías
-- (Config.Categories) quedan fuera a propósito: no se pueden cambiar desde aquí.
local Util = CarHud.Util
local Admin = {}

-- Teclas válidas del mapeador de teclado de FiveM (nombres en mayúsculas).
local KEYS = {}
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.') do KEYS[c] = true end
for i = 1, 12 do KEYS['F' .. i] = true end
for i = 0, 9 do KEYS['NUMPAD' .. i] = true end
for _, k in ipairs({ 'LEFT', 'RIGHT', 'UP', 'DOWN', 'PAGEUP', 'PAGEDOWN', 'HOME', 'END', 'INSERT', 'DELETE',
    'LSHIFT', 'RSHIFT', 'LCONTROL', 'RCONTROL', 'LMENU', 'RMENU', 'SPACE', 'TAB', 'CAPITAL', 'BACK', 'RETURN',
    'MULTIPLY', 'ADD', 'SUBTRACT', 'DECIMAL', 'DIVIDE', 'PERIOD', 'COMMA', 'MINUS', 'PLUS', 'GRAVE' }) do
    KEYS[k] = true
end
Admin.KEYS = KEYS

local EJECTION_CATEGORIES = { 'car', 'motorcycle', 'boat', 'plane', 'heli' }

-- section · id (ruta en Config) · type · límites. Los textos están en la NUI.
Admin.FIELDS = {
    -- Cinturón y accidentes
    { section = 'seatbelt', id = 'Features.seatbelt', type = 'bool' },
    { section = 'seatbelt', id = 'Seatbelt.key', type = 'key' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.enabled', type = 'bool' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.categories', type = 'list', options = EJECTION_CATEGORIES },
    { section = 'seatbelt', id = 'Seatbelt.ejection.allowModels', type = 'models' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.denyModels', type = 'models' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.minSpeed', type = 'number', min = 20, max = 250, step = 5, unit = 'km/h' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.minDelta', type = 'number', min = 10, max = 200, step = 5, unit = 'km/h' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.minRatio', type = 'number', min = 0.1, max = 0.95, step = 0.05, unit = 'ratio' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.window', type = 'int', min = 50, max = 1000, step = 10, unit = 'ms' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.horizontalForce', type = 'number', min = 0, max = 2, step = 0.05, unit = 'x' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.verticalForce', type = 'number', min = 0, max = 12, step = 0.5, unit = 'm/s' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.ragdoll', type = 'int', min = 500, max = 15000, step = 250, unit = 'ms' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.damageEnabled', type = 'bool' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.damage', type = 'int', min = 0, max = 100, step = 1, unit = 'hp' },
    { section = 'seatbelt', id = 'Seatbelt.ejection.cooldown', type = 'int', min = 0, max = 60000, step = 500, unit = 'ms' },
    { section = 'seatbelt', id = 'Seatbelt.warnSound', type = 'bool' },
    { section = 'seatbelt', id = 'Seatbelt.warnSpeed', type = 'number', min = 0, max = 200, step = 5, unit = 'km/h' },
    { section = 'seatbelt', id = 'Seatbelt.warnInterval', type = 'int', min = 1000, max = 60000, step = 500, unit = 'ms' },
    { section = 'seatbelt', id = 'Seatbelt.lockExit', type = 'bool' },
    -- Motor
    { section = 'engine', id = 'Features.engine', type = 'bool' },
    { section = 'engine', id = 'Engine.key', type = 'key' },
    -- Luces
    { section = 'lights', id = 'Features.lights', type = 'bool' },
    { section = 'lights', id = 'Lights.key', type = 'key' },
    { section = 'lights', id = 'Lights.longPress', type = 'int', min = 150, max = 1000, step = 10, unit = 'ms' },
    { section = 'lights', id = 'Features.indicators', type = 'bool' },
    { section = 'lights', id = 'Lights.leftKey', type = 'key' },
    { section = 'lights', id = 'Lights.rightKey', type = 'key' },
    { section = 'lights', id = 'Lights.hazardKey', type = 'key' },
    -- Crucero
    { section = 'cruise', id = 'Features.cruise', type = 'bool' },
    { section = 'cruise', id = 'Cruise.key', type = 'key' },
    { section = 'cruise', id = 'Cruise.upKey', type = 'key' },
    { section = 'cruise', id = 'Cruise.downKey', type = 'key' },
    { section = 'cruise', id = 'Cruise.minSpeed', type = 'number', min = 10, max = 150, step = 5, unit = 'km/h' },
    { section = 'cruise', id = 'Cruise.step', type = 'int', min = 1, max = 20, step = 1, unit = 'unit' },
    { section = 'cruise', id = 'Cruise.maxAirTime', type = 'int', min = 200, max = 5000, step = 100, unit = 'ms' },
    -- Nitro
    { section = 'nitro', id = 'Features.nitro', type = 'bool' },
    { section = 'nitro', id = 'Nitro.key', type = 'key' },
    { section = 'nitro', id = 'Nitro.power', type = 'number', min = 1, max = 5, step = 0.1, unit = 'x' },
    { section = 'nitro', id = 'Nitro.consumption', type = 'number', min = 1, max = 100, step = 0.5, unit = '/s' },
    { section = 'nitro', id = 'Nitro.minToActivate', type = 'number', min = 0, max = 50, step = 1, unit = 'u' },
    { section = 'nitro', id = 'Nitro.cooldown', type = 'int', min = 0, max = 10000, step = 100, unit = 'ms' },
    { section = 'nitro', id = 'Nitro.defaultCapacity', type = 'number', min = 10, max = 1000, step = 5, unit = 'u' },
    { section = 'nitro', id = 'Nitro.maxCapacity', type = 'number', min = 10, max = 1000, step = 5, unit = 'u' },
    { section = 'nitro', id = 'Nitro.exhaustFx', type = 'bool' },
}

local byId = {}
for _, field in ipairs(Admin.FIELDS) do byId[field.id] = field end
Admin.byId = byId

------------------------------------------------------------------------------
-- Rutas y copias
------------------------------------------------------------------------------
local function split(id)
    local parts = {}
    for part in id:gmatch('[^%.]+') do parts[#parts + 1] = part end
    return parts
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
Admin.copy = copy

function Admin.get(id)
    local node = Config
    for _, part in ipairs(split(id)) do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end

local function set(id, value)
    local parts = split(id)
    local node = Config
    for i = 1, #parts - 1 do
        node[parts[i]] = node[parts[i]] or {}
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
Admin.same = same

------------------------------------------------------------------------------
-- Validación de un valor según su campo. Devuelve valor normalizado o nil, error.
------------------------------------------------------------------------------
function Admin.validate(id, value)
    local field = byId[id]
    if not field then return nil, 'unknown' end
    local t = field.type
    if t == 'bool' then
        if type(value) ~= 'boolean' then return nil, 'type' end
        return value
    elseif t == 'number' or t == 'int' then
        if type(value) ~= 'number' then return nil, 'type' end
        local n = Util.number(value)
        if not n then return nil, 'type' end
        if t == 'int' and n ~= math.floor(n) then return nil, 'int' end
        if n < field.min or n > field.max then return nil, 'range' end
        return n
    elseif t == 'key' then
        if type(value) ~= 'string' then return nil, 'type' end
        local key = value:upper()
        if not KEYS[key] then return nil, 'key' end
        return key
    elseif t == 'list' then
        if type(value) ~= 'table' then return nil, 'type' end
        local allowed, seen, out = {}, {}, {}
        for _, option in ipairs(field.options) do allowed[option] = true end
        for _, item in ipairs(value) do
            if type(item) ~= 'string' or not allowed[item] then return nil, 'option' end
            if not seen[item] then
                seen[item] = true
                out[#out + 1] = item
            end
        end
        -- Orden estable según las opciones
        table.sort(out, function(a, b)
            local ia, ib
            for i, o in ipairs(field.options) do
                if o == a then ia = i end
                if o == b then ib = i end
            end
            return ia < ib
        end)
        return out
    elseif t == 'models' then
        if type(value) ~= 'table' or #value > 50 then return nil, 'type' end
        local seen, out = {}, {}
        for _, item in ipairs(value) do
            if type(item) ~= 'string' then return nil, 'type' end
            local name = Util.trim(item):lower()
            if not name:match('^[%w_%-]+$') or #name > 32 then return nil, 'model' end
            if not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
        return out
    end
    return nil, 'type'
end

-- Comprobaciones entre campos sobre el conjunto final de valores.
function Admin.crossCheck(values)
    local get = function(id) return values[id] end
    if get('Nitro.defaultCapacity') > get('Nitro.maxCapacity') then return 'Nitro.defaultCapacity', 'capacity' end
    if get('Nitro.minToActivate') > get('Nitro.maxCapacity') then return 'Nitro.minToActivate', 'capacity' end
    return nil
end

------------------------------------------------------------------------------
-- Predeterminados (config.lua) y aplicación de cambios guardados
------------------------------------------------------------------------------
local defaults = nil

function Admin.captureDefaults()
    defaults = {}
    for _, field in ipairs(Admin.FIELDS) do defaults[field.id] = copy(Admin.get(field.id)) end
    return defaults
end

function Admin.defaults()
    return defaults or Admin.captureDefaults()
end

-- Valores actuales (predeterminados + cambios), por id.
function Admin.current(overrides)
    local out = {}
    for _, field in ipairs(Admin.FIELDS) do
        local v = overrides and overrides[field.id]
        if v == nil then v = Admin.defaults()[field.id] end
        out[field.id] = copy(v)
    end
    return out
end

-- Escribe en Config los valores efectivos. Los no sobrescritos vuelven al predeterminado.
function Admin.apply(overrides)
    Admin.defaults()
    for id, value in pairs(Admin.current(overrides)) do set(id, copy(value)) end
end

-- Limpia unos cambios guardados: descarta lo desconocido o inválido y lo que
-- coincide con el predeterminado. Se usa al cargar data/admin.json y al
-- recibir el estado replicado.
function Admin.sanitize(overrides)
    local out = {}
    if type(overrides) ~= 'table' then return out end
    for id, value in pairs(overrides) do
        local clean = byId[id] and Admin.validate(id, value)
        if clean ~= nil and not same(clean, Admin.defaults()[id]) then out[id] = clean end
    end
    local current = Admin.current(out)
    local bad = Admin.crossCheck(current)
    if bad then out[bad] = nil end
    return out
end

------------------------------------------------------------------------------
-- ¿Se permite la expulsión en este vehículo? Pura: la usan el cliente y las pruebas.
------------------------------------------------------------------------------
function Admin.ejectionAllowed(category, modelHash, hashFn)
    if category == 'bicycle' or category == 'train' then return false end
    local ej = Config.Seatbelt.ejection
    for _, name in ipairs(ej.denyModels or {}) do
        if hashFn(name) == modelHash then return false end
    end
    for _, name in ipairs(ej.allowModels or {}) do
        if hashFn(name) == modelHash then return true end
    end
    for _, allowed in ipairs(ej.categories or {}) do
        if allowed == category then return true end
    end
    return false
end

CarHud.Admin = Admin

Admin.captureDefaults()
