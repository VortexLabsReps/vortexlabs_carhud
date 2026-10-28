-- Ajustes de administración (cliente). Aplica los valores que publica el
-- servidor en GlobalState al arrancar (antes de registrar teclas) y en caliente.
-- El menú solo se abre con los datos que el servidor envía tras comprobar el
-- permiso; guardar vuelve a comprobarlo allí.
local Admin = CarHud.Admin
local NUI = CarHud.NUI
local STATE_KEY = 'fcarhud_admin'

local AdminMenu = { open = false }

local function applyState(state)
    local values = type(state) == 'table' and state.values or nil
    Admin.apply(Admin.sanitize(values))
end

applyState(GlobalState[STATE_KEY])

-- Cambio en caliente: primero se recalcula el perfil del vehículo actual (las
-- funciones activas dependen de Config.Features) y luego se avisa a los módulos.
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    applyState(value)
    local S = CarHud.State
    if S.veh ~= 0 and DoesEntityExist(S.veh) then
        S.profile = CarHud.Vehicle.profile(S.veh)
        S.scaleKmh = S.profile.scaleKmh
    end
    CarHud.emit('config')
end)

------------------------------------------------------------------------------
-- Menú (NUI, separado del menú personal)
------------------------------------------------------------------------------
function AdminMenu.hide(fromNui)
    if not AdminMenu.open then return end
    AdminMenu.open = false
    SetNuiFocus(false, false)
    if not fromNui then NUI.send({ t = 'adminClose' }) end
end

RegisterNetEvent('vortexlabs_carhud:admin:data', function(data)
    if type(data) ~= 'table' or not NUI.ready then return end
    if CarHud.Menu.open then CarHud.Menu.hide() end
    AdminMenu.open = true
    AdminMenu.acknowledged = false
    AdminMenu.openId = (AdminMenu.openId or 0) + 1
    local id = AdminMenu.openId
    SetNuiFocus(true, true)
    local keys = {}
    for key in pairs(Admin.KEYS) do keys[#keys + 1] = key end
    table.sort(keys)
    NUI.send({ t = 'adminOpen', fields = Admin.FIELDS, keys = keys, values = data.values, defaults = data.defaults })
    SetTimeout(1500, function()
        if AdminMenu.open and AdminMenu.openId == id and not AdminMenu.acknowledged then AdminMenu.hide() end
    end)
    CreateThread(function()
        while AdminMenu.open and AdminMenu.openId == id do
            if IsPauseMenuActive() then AdminMenu.hide() end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('vortexlabs_carhud:admin:result', function(result)
    if type(result) == 'table' then NUI.send({ t = 'adminResult', result = result }) end
end)

RegisterNUICallback('adminOpened', function(_, cb)
    AdminMenu.acknowledged = true
    cb({})
end)

RegisterNUICallback('adminSave', function(data, cb)
    if AdminMenu.open and type(data) == 'table' and type(data.values) == 'table' then
        TriggerServerEvent('vortexlabs_carhud:admin:save', data.values)
    end
    cb({})
end)

RegisterNUICallback('adminClose', function(_, cb)
    AdminMenu.hide(true)
    cb({})
end)

RegisterCommand(Config.Admin.command, function()
    TriggerServerEvent('vortexlabs_carhud:admin:open')
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Admin.command, CarHud.T('admin_help'))

-- Diagnóstico de expulsión: activar/desactivar (el servidor comprueba el permiso).
RegisterCommand(Config.Admin.crashDiagCommand, function()
    TriggerServerEvent('vortexlabs_carhud:admin:crashdiag')
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Admin.crashDiagCommand, CarHud.T('crashdiag_help'))

CarHud.on('stop', function()
    if AdminMenu.open then SetNuiFocus(false, false) end
end)

CarHud.AdminMenu = AdminMenu
