-- Esquema y validación de las preferencias del jugador. Cualquier valor que
-- llega de la KVP o de la NUI pasa por sanitize(): lo desconocido se descarta
-- y lo que el servidor no permite vuelve al valor por defecto.
local Util = CarHud.Util
local Settings = {}

Settings.VERSION = 1
Settings.MODULES = { 'rpm', 'throttle', 'fuel', 'engine', 'nitro', 'telltales', 'altitude', 'notices' }

local function defaultScale()
    return Util.clamp(1.0, Config.Player.scaleMin, Config.Player.scaleMax)
end

-- Posición y tamaño predeterminados de la ubicación (Config.Location.default).
local function locationDefault()
    local d = Config.Location and Config.Location.default or {}
    return {
        x = Util.clamp(Util.number(d.x) or 0, -0.6, 0.6),
        y = Util.clamp(Util.number(d.y) or 0, -0.6, 0.6),
        scale = Util.clamp(Util.number(d.scale) or 1.0, Config.Player.scaleMin, Config.Player.scaleMax),
    }
end

function Settings.defaults()
    local modules = {}
    for _, name in ipairs(Settings.MODULES) do modules[name] = true end
    local accent = Util.isHexColor(Config.Hud.accent) and Config.Hud.accent:upper() or '#FE3555'
    return {
        v = Settings.VERSION,
        unit = Config.Hud.defaultUnit == 'mph' and 'mph' or 'kmh',
        accent = accent,
        values = false,
        volume = Util.clamp(Config.Player.defaultVolume or 0.6, 0, Config.Player.maxVolume or 1),
        modules = modules,
        cluster = { scale = defaultScale(), opacity = 1.0 },
        -- Ubicación: x/y = desplazamiento respecto al minimapa en fracciones del alto de
        -- pantalla; sin x/y se usa Config.Location.default (también al restaurar).
        location = { enabled = true, scale = locationDefault().scale },
    }
end

local function sanitizeLayout(target, source, rules)
    if type(source) ~= 'table' then return end
    local scale = Util.number(source.scale)
    if scale then target.scale = Util.clamp(scale, rules.scaleMin, rules.scaleMax) end
    local opacity = Util.number(source.opacity)
    if opacity then target.opacity = Util.clamp(opacity, rules.opacityMin or 0.4, 1.0) end
    local x, y = Util.number(source.x), Util.number(source.y)
    if x and y then
        target.x = Util.clamp(x, 0, 1)
        target.y = Util.clamp(y, 0, 1)
    end
end

function Settings.sanitize(input)
    local result = Settings.defaults()
    if type(input) ~= 'table' then return result end
    local rules = Config.Player

    if rules.allowUnit and (input.unit == 'kmh' or input.unit == 'mph') then result.unit = input.unit end
    if rules.allowColor and Util.isHexColor(input.accent) then result.accent = input.accent:upper() end
    if type(input.values) == 'boolean' then result.values = input.values end

    local volume = Util.number(input.volume)
    if volume then result.volume = Util.clamp(volume, 0, rules.maxVolume or 1) end

    if rules.allowModules and type(input.modules) == 'table' then
        for _, name in ipairs(Settings.MODULES) do
            if type(input.modules[name]) == 'boolean' then result.modules[name] = input.modules[name] end
        end
    end

    if rules.allowLayout then
        sanitizeLayout(result.cluster, input.cluster, rules)
    end

    local loc = input.location
    if type(loc) == 'table' then
        if type(loc.enabled) == 'boolean' then result.location.enabled = loc.enabled end
        if rules.allowLayout then
            local scale = Util.number(loc.scale)
            if scale then result.location.scale = Util.clamp(scale, rules.scaleMin, rules.scaleMax) end
            local x, y = Util.number(loc.x), Util.number(loc.y)
            if x and y then
                result.location.x = Util.clamp(x, -0.6, 0.6)
                result.location.y = Util.clamp(y, -0.6, 0.6)
            end
        end
    end
    return result
end

-- Restricciones que la NUI necesita para construir el menú.
function Settings.rules()
    return {
        allowUnit = Config.Player.allowUnit == true,
        allowColor = Config.Player.allowColor == true,
        allowLayout = Config.Player.allowLayout == true,
        allowModules = Config.Player.allowModules == true,
        scaleMin = Config.Player.scaleMin,
        scaleMax = Config.Player.scaleMax,
        opacityMin = Config.Player.opacityMin or 0.4,
        maxVolume = Config.Player.maxVolume,
        locationDefault = locationDefault(),
        features = {
            nitro = Config.Features.nitro == true,
            seatbelt = Config.Features.seatbelt == true,
            location = Config.Location ~= nil and Config.Location.enabled == true,
        },
    }
end

CarHud.Settings = Settings
