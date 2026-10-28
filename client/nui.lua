-- Comunicación con la NUI. Hasta que la página avisa de que está lista se
-- conserva solo el último mensaje de estado de cada tipo; las lecturas rápidas
-- y los avisos efímeros se descartan.
local Util = CarHud.Util
local NUI = { ready = false, sent = 0 }

local pending = {}
local pendingOrder = {}
local KEEP = { profile = true, visible = true, s = true, safe = true, settings = true }

function NUI.send(message)
    if NUI.ready then
        SendNUIMessage(message)
        NUI.sent = NUI.sent + 1
    elseif KEEP[message.t] then
        if not pending[message.t] then table.insert(pendingOrder, message.t) end
        pending[message.t] = message
    end
end

-- Texto de un aviso en Lua (para notificaciones del framework).
function NUI.translate(key, vars)
    if vars and vars.speed then
        local mph = CarHud.State.settings and CarHud.State.settings.unit == 'mph'
        local value = Util.round(vars.speed * (mph and Util.MPH or Util.KMH))
        return CarHud.T(key, ('%d %s'):format(value, mph and 'mph' or 'km/h'))
    end
    return CarHud.T(key)
end

RegisterNUICallback('ready', function(_, cb)
    NUI.ready = true
    SendNUIMessage({
        t = 'init',
        lang = CarHud.Locale.lang,
        strings = CarHud.Locale.ui,
        fallback = CarHud.Locale.fallback.ui,
        settings = CarHud.State.settings,
        rules = CarHud.Settings.rules(),
        thresholds = { fuel = Config.Warnings.fuel, engine = Config.Warnings.engine },
    })
    for _, kind in ipairs(pendingOrder) do
        if pending[kind] then SendNUIMessage(pending[kind]) end
    end
    pending, pendingOrder = {}, {}
    CarHud.emit('nuiReady')
    cb({})
end)

CarHud.NUI = NUI
