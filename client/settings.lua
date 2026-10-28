-- Preferencias del jugador: guardadas en la KVP del cliente (sin SQL), validadas
-- al cargar y al recibir cada cambio de la NUI. El menú es lo único que toma el
-- foco y siempre lo libera (cerrar, Escape, menú de pausa o parada del recurso).
local Settings = CarHud.Settings
local NUI = CarHud.NUI
local S = CarHud.State

local KVP = 'vortexlabs_carhud:settings'
local Menu = { open = false }

local function load()
    local raw = GetResourceKvpString(KVP)
    local data = nil
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok then data = decoded end
    end
    S.settings = Settings.sanitize(data)
end

local function store()
    SetResourceKvp(KVP, json.encode(S.settings))
end

local function apply(data)
    S.settings = Settings.sanitize(data)
    store()
    NUI.send({ t = 'settings', settings = S.settings })
end

function Menu.show()
    if Menu.open or not NUI.ready then return end
    Menu.open = true
    Menu.acknowledged = false
    Menu.openId = (Menu.openId or 0) + 1
    local id = Menu.openId
    SetNuiFocus(true, true)
    NUI.send({ t = 'openSettings' })
    -- Si la interfaz no confirma que el menú está a la vista, se libera el foco:
    -- el jugador nunca queda con el ratón capturado y sin menú.
    SetTimeout(1500, function()
        if Menu.open and Menu.openId == id and not Menu.acknowledged then Menu.hide() end
    end)
    -- Red de seguridad: si se abre el menú de pausa, se cierra el de ajustes.
    CreateThread(function()
        while Menu.open do
            if IsPauseMenuActive() then Menu.hide() end
            Wait(250)
        end
    end)
end

function Menu.hide(fromNui)
    if not Menu.open then return end
    Menu.open = false
    SetNuiFocus(false, false)
    if not fromNui then NUI.send({ t = 'closeSettings' }) end
end

RegisterNUICallback('opened', function(_, cb)
    Menu.acknowledged = true
    cb({})
end)

RegisterNUICallback('save', function(data, cb)
    if type(data) == 'table' then apply(data.settings) end
    cb({})
end)

RegisterNUICallback('reset', function(_, cb)
    DeleteResourceKvp(KVP)
    S.settings = Settings.defaults()
    NUI.send({ t = 'settings', settings = S.settings })
    cb({})
end)

RegisterNUICallback('close', function(data, cb)
    if type(data) == 'table' and data.settings then apply(data.settings) end
    Menu.hide(true)
    cb({})
end)

load()
CarHud.Menu = Menu
