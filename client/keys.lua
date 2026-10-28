-- Teclas reasignables (Ajustes → Asignación de teclas → FiveM). Se registran
-- todas para que el menú de administración pueda activar funciones en caliente;
-- cada función comprueba si está activa. Las teclas predeterminadas salen de
-- Config (incluidos los cambios de /carhudadmin) al arrancar el recurso: un
-- cambio de tecla llega a cada jugador al reconectar y, como hace FiveM, no
-- sustituye una tecla que el jugador ya haya personalizado. Los comandos llevan
-- el prefijo fcarhud_ para no chocar con otros recursos.
local function bind(command, descriptionKey, key, onPress, onRelease)
    if onRelease then
        RegisterCommand('+' .. command, onPress, false)
        RegisterCommand('-' .. command, onRelease, false)
        RegisterKeyMapping('+' .. command, CarHud.T(descriptionKey), 'keyboard', key)
    else
        RegisterCommand(command, onPress, false)
        RegisterKeyMapping(command, CarHud.T(descriptionKey), 'keyboard', key)
    end
end

local Keys = {}

-- La tecla del cinturón solo existe con la mecánica propia; si un cinturón
-- externo se detiene más tarde y el modo pasa a 'own', se registra entonces.
local seatbeltBound = false
function Keys.ensureSeatbelt()
    if seatbeltBound or CarHud.Seatbelt.mode ~= 'own' then return end
    seatbeltBound = true
    bind('fcarhud_seatbelt', 'key_seatbelt', Config.Seatbelt.key, function() CarHud.Seatbelt.toggle() end)
end
Keys.ensureSeatbelt()
CarHud.Keys = Keys

bind('fcarhud_lights', 'key_lights', Config.Lights.key,
    function() CarHud.Lights.press() end,
    function() CarHud.Lights.release() end)

bind('fcarhud_left', 'key_left', Config.Lights.leftKey, function() CarHud.Lights.indicator('left') end)
bind('fcarhud_right', 'key_right', Config.Lights.rightKey, function() CarHud.Lights.indicator('right') end)
bind('fcarhud_hazard', 'key_hazard', Config.Lights.hazardKey, function() CarHud.Lights.indicator('hazard') end)

bind('fcarhud_cruise', 'key_cruise', Config.Cruise.key, function() CarHud.Cruise.toggle() end)
bind('fcarhud_cruise_up', 'key_cruise_up', Config.Cruise.upKey, function() CarHud.Cruise.adjust(1) end)
bind('fcarhud_cruise_down', 'key_cruise_down', Config.Cruise.downKey, function() CarHud.Cruise.adjust(-1) end)

bind('fcarhud_engine', 'key_engine', Config.Engine.key, function() CarHud.Engine.toggle() end)

bind('fcarhud_nitro', 'key_nitro', Config.Nitro.key,
    function() CarHud.Nitro.press() end,
    function() CarHud.Nitro.release() end)

-- Ajustes: /carhud · /carhud perf [segundos] · /carhud layout (imprime la posición
-- guardada en la consola F8, lista para copiarla como predeterminada en config.lua)
RegisterCommand(Config.Player.command, function(_, args)
    if args[1] == 'perf' then return CarHud.Perf.start(args[2]) end
    if args[1] == 'layout' then
        local s = CarHud.State.settings or {}
        local w, h = GetActiveScreenResolution()
        print(('[vortexlabs_carhud] layout %s res=%dx%d safe=%.3f'):format(
            json.encode({ cluster = s.cluster, location = s.location }), w, h, GetSafeZoneSize()))
        return
    end
    CarHud.Menu.show()
end, false)
if Config.Player.settingsKey and Config.Player.settingsKey ~= '' then
    RegisterKeyMapping(Config.Player.command, CarHud.T('key_settings'), 'keyboard', Config.Player.settingsKey)
end
TriggerEvent('chat:addSuggestion', '/' .. Config.Player.command, CarHud.T('cmd_help'))
