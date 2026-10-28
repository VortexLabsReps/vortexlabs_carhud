-- Adaptadores de framework (servidor): solo para comprobar permisos de
-- administración. Las ACE funcionan siempre, con o sin framework.
local Framework = { name = 'standalone' }
local RESOURCES = { qbox = 'qbx_core', qbcore = 'qb-core', esx = 'es_extended' }

local function started(resource)
    return GetResourceState(resource) == 'started'
end

function Framework.refresh()
    local wanted = Config.Framework
    if wanted ~= 'auto' then
        Framework.name = (wanted == 'standalone' or RESOURCES[wanted]) and wanted or 'standalone'
        return
    end
    if started('qbx_core') then Framework.name = 'qbox'
    elseif started('qb-core') then Framework.name = 'qbcore'
    elseif started('es_extended') then Framework.name = 'esx'
    else Framework.name = 'standalone' end
end

local function frameworkAdmin(source)
    local resource = RESOURCES[Framework.name]
    if not resource or not started(resource) then return false end
    local groups = Config.Permissions.frameworkGroups or {}

    if Framework.name == 'qbox' then
        -- Qbox usa ACE para los grupos (add_ace group.admin admin allow).
        for _, group in ipairs(groups) do
            if IsPlayerAceAllowed(source, group) then return true end
        end
        return false
    end

    if Framework.name == 'qbcore' then
        local ok, allowed = pcall(function()
            local QBCore = exports['qb-core']:GetCoreObject()
            for _, group in ipairs(groups) do
                if QBCore.Functions.HasPermission(source, group) then return true end
            end
            return false
        end)
        return ok and allowed == true
    end

    if Framework.name == 'esx' then
        local ok, allowed = pcall(function()
            local ESX = exports.es_extended:getSharedObject()
            local player = ESX.GetPlayerFromId(source)
            if not player then return false end
            local playerGroup = player.getGroup()
            for _, group in ipairs(groups) do
                if playerGroup == group then return true end
            end
            return false
        end)
        return ok and allowed == true
    end
    return false
end

function Framework.isAdmin(source)
    if source == 0 then return true end
    if IsPlayerAceAllowed(source, Config.Permissions.ace) then return true end
    return frameworkAdmin(source)
end

AddEventHandler('onResourceStart', function(resource)
    for _, name in pairs(RESOURCES) do
        if name == resource then Framework.refresh() return end
    end
end)
AddEventHandler('onResourceStop', function(resource)
    for _, name in pairs(RESOURCES) do
        if name == resource then SetTimeout(0, Framework.refresh) return end
    end
end)

Framework.refresh()
CarHud.Framework = Framework
