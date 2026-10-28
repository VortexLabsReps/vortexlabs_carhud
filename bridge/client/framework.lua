-- Adaptadores de framework (cliente). El núcleo solo usa CarHud.Framework.ready()
-- y CarHud.Framework.notify(); nada más depende del framework.
-- Cada llamada externa va protegida: si el framework se reinicia o se detiene,
-- el adaptador degrada a standalone sin errores continuos.
local Framework = { name = 'standalone' }

local RESOURCES = { qbox = 'qbx_core', qbcore = 'qb-core', esx = 'es_extended' }
local loggedIn = nil      -- estado conocido por eventos (nil = desconocido)
local core = nil          -- objeto compartido (QBCore / ESX) en caché

local function started(resource)
    return GetResourceState(resource) == 'started'
end

local function detect()
    local wanted = Config.Framework
    if wanted ~= 'auto' then
        if wanted ~= 'standalone' and not RESOURCES[wanted] then wanted = 'standalone' end
        return wanted
    end
    -- Qbox primero: qbx_core también proporciona 'qb-core' a efectos de compatibilidad.
    if started('qbx_core') then return 'qbox' end
    if started('qb-core') then return 'qbcore' end
    if started('es_extended') then return 'esx' end
    return 'standalone'
end

local function getCore()
    if core then return core end
    local ok, result
    if Framework.name == 'qbcore' then
        ok, result = pcall(function() return exports['qb-core']:GetCoreObject() end)
    elseif Framework.name == 'esx' then
        ok, result = pcall(function() return exports.es_extended:getSharedObject() end)
    end
    if ok and type(result) == 'table' then core = result end
    return core
end

local function available()
    local resource = RESOURCES[Framework.name]
    return resource ~= nil and started(resource)
end

function Framework.refresh()
    Framework.name = detect()
    core = nil
    loggedIn = nil
end

-- ¿Ha cargado el personaje? Sin framework (o con el framework detenido) siempre true.
function Framework.ready()
    if not Config.Hud.requirePlayerLoaded or Framework.name == 'standalone' or not available() then
        return true
    end
    if loggedIn ~= nil then return loggedIn end
    if Framework.name == 'qbox' or Framework.name == 'qbcore' then
        local state = LocalPlayer.state.isLoggedIn
        if state ~= nil then return state == true end
        return true
    end
    if Framework.name == 'esx' then
        local esx = getCore()
        if esx and esx.IsPlayerLoaded then
            local ok, result = pcall(esx.IsPlayerLoaded)
            if ok then return result == true end
        end
        return true
    end
    return true
end

function Framework.notify(message, kind)
    if not available() then return false end
    local ok = false
    if Framework.name == 'qbox' then
        ok = pcall(function() exports.qbx_core:Notify(message, kind or 'inform') end)
    elseif Framework.name == 'qbcore' then
        local qb = getCore()
        if qb and qb.Functions and qb.Functions.Notify then
            ok = pcall(qb.Functions.Notify, message, kind == 'inform' and 'primary' or kind)
        end
    elseif Framework.name == 'esx' then
        local esx = getCore()
        if esx and esx.ShowNotification then ok = pcall(esx.ShowNotification, message) end
    end
    return ok
end

-- Eventos nativos de carga/descarga de personaje.
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() loggedIn = true end)
AddEventHandler('QBCore:Client:OnPlayerUnload', function() loggedIn = false end)
AddEventHandler('esx:playerLoaded', function() loggedIn = true end)
AddEventHandler('esx:onPlayerLogout', function() loggedIn = false end)

-- Reinicio de un framework: se vuelve a detectar y se descarta la caché.
AddEventHandler('onClientResourceStart', function(resource)
    for _, name in pairs(RESOURCES) do
        if name == resource then Framework.refresh() return end
    end
end)
AddEventHandler('onClientResourceStop', function(resource)
    for _, name in pairs(RESOURCES) do
        if name == resource then core = nil; loggedIn = nil return end
    end
end)

Framework.refresh()
CarHud.Framework = Framework
