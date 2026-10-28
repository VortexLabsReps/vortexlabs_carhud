-- Menú de administración (servidor). Los permisos se comprueban aquí en cada
-- apertura y en cada guardado: ocultar el menú en el cliente no basta.
-- Cambios atómicos: si un solo valor no es válido no se aplica ninguno.
-- Se guardan en data/admin.json (sin base de datos) y se replican a todos los
-- jugadores con GlobalState, que también reciben quienes se conectan después.
local Admin = CarHud.Admin
local cfg = Config.Admin
local DATA_FILE = 'data/admin.json'
local RESOURCE = GetCurrentResourceName()
local STATE_KEY = 'fcarhud_admin'

local overrides = {}
local revision = 0
local rate = {}

local function limited(source, event, interval)
    local now = GetGameTimer()
    rate[source] = rate[source] or {}
    if rate[source][event] and now - rate[source][event] < interval then return true end
    rate[source][event] = now
    return false
end

local function publish()
    revision = revision + 1
    GlobalState:set(STATE_KEY, { rev = revision, values = overrides }, true)
end

local function save()
    if not cfg.persist then return end
    SaveResourceFile(RESOURCE, DATA_FILE, json.encode(overrides), -1)
end

local function load()
    if not cfg.persist then return end
    local raw = LoadResourceFile(RESOURCE, DATA_FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if ok then overrides = Admin.sanitize(data) end
end

local function playerLabel(source)
    if source == 0 then return CarHud.T('console_label') end
    return ('%s (%d)'):format(GetPlayerName(source) or '?', source)
end

-- Valida un lote de cambios {id = valor}. Devuelve los nuevos cambios guardados o errores.
local function prepare(changes)
    if type(changes) ~= 'table' then return nil, { { id = '*', error = 'type' } } end
    local errors, count = {}, 0
    local pending = Admin.copy(overrides)
    for id, value in pairs(changes) do
        count = count + 1
        if count > #Admin.FIELDS then return nil, { { id = '*', error = 'size' } } end
        local clean, err = Admin.validate(id, value)
        if clean == nil then
            errors[#errors + 1] = { id = tostring(id), error = err }
        elseif Admin.same(clean, Admin.defaults()[id]) then
            pending[id] = nil
        else
            pending[id] = clean
        end
    end
    if #errors == 0 then
        local badId, err = Admin.crossCheck(Admin.current(pending))
        if badId then errors[#errors + 1] = { id = badId, error = err } end
    end
    if #errors > 0 then return nil, errors end
    return pending
end

local function changedIds(before, after)
    local ids = {}
    for _, field in ipairs(Admin.FIELDS) do
        local a = before[field.id]
        local b = after[field.id]
        if a == nil then a = Admin.defaults()[field.id] end
        if b == nil then b = Admin.defaults()[field.id] end
        if not Admin.same(a, b) then ids[#ids + 1] = field.id end
    end
    return ids
end

RegisterNetEvent('vortexlabs_carhud:admin:open', function()
    local source = source
    if limited(source, 'open', 1000) then return end
    if not CarHud.Framework.isAdmin(source) then
        TriggerClientEvent('vortexlabs_carhud:notify', source, CarHud.T('admin_no_permission'), 'danger')
        return
    end
    TriggerClientEvent('vortexlabs_carhud:admin:data', source, {
        values = Admin.current(overrides),
        defaults = Admin.defaults(),
    })
end)

RegisterNetEvent('vortexlabs_carhud:admin:save', function(changes)
    local source = source
    if limited(source, 'save', 1000) then
        TriggerClientEvent('vortexlabs_carhud:admin:result', source, { ok = false, errors = { { id = '*', error = 'rate' } } })
        return
    end
    -- Permiso comprobado en cada modificación.
    if not CarHud.Framework.isAdmin(source) then
        TriggerClientEvent('vortexlabs_carhud:admin:result', source, { ok = false, errors = { { id = '*', error = 'permission' } } })
        print('[vortexlabs_carhud] ' .. CarHud.T('admin_denied_log', playerLabel(source)))
        return
    end
    local pending, errors = prepare(changes)
    if not pending then
        TriggerClientEvent('vortexlabs_carhud:admin:result', source, { ok = false, errors = errors })
        return
    end
    local ids = changedIds(overrides, pending)
    overrides = pending
    Admin.apply(overrides)
    save()
    publish()
    if #ids > 0 then
        print('[vortexlabs_carhud] ' .. CarHud.T('admin_changed_log', playerLabel(source), #ids, table.concat(ids, ', ')))
    end
    TriggerClientEvent('vortexlabs_carhud:admin:result', source, { ok = true, values = Admin.current(overrides), changed = #ids })
end)

-- Diagnóstico de expulsión (/carhudcrash): solo administradores. No cambia nada
-- del servidor; únicamente autoriza al cliente a mostrar sus propias muestras.
RegisterNetEvent('vortexlabs_carhud:admin:crashdiag', function()
    local source = source
    if limited(source, 'crashdiag', 500) then return end
    if not CarHud.Framework.isAdmin(source) then
        TriggerClientEvent('vortexlabs_carhud:notify', source, CarHud.T('admin_no_permission'), 'danger')
        return
    end
    TriggerClientEvent('vortexlabs_carhud:crashdiag', source, true)
end)

AddEventHandler('playerDropped', function()
    rate[source] = nil
end)

load()
Admin.apply(overrides)
publish()

CarHud.AdminServer = { prepare = prepare, overrides = function() return overrides end }
