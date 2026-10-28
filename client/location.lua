-- Ubicación sobre el minimapa: calle, zona y rumbo leídos con natives (válido en
-- standalone; mismas fuentes que los getters de Qbox: GetStreetNameAtCoord /
-- GetStreetNameFromHashKey y GetLabelText(GetNameOfZone)). La calle y la zona se
-- leen con frecuencia moderada y solo se envían si cambian; el rumbo se suaviza
-- con histéresis cerca del límite entre puntos cardinales.
-- No decide su visibilidad por su cuenta: la decide el bucle del HUD
-- (client/telemetry.lua) y la envía en el mismo mensaje que la del velocímetro.
local Geo = CarHud.Geo
local NUI = CarHud.NUI
local S = CarHud.State
local cfg = Config.Location

local Location = {}
local sent = {}

-- Condiciones propias de la ubicación, además de las del HUD.
function Location.allowed()
    if not cfg.enabled then return false end
    local prefs = S.settings and S.settings.location
    if prefs and prefs.enabled == false then return false end
    return not IsRadarHidden() and not IsBigmapActive()
end

-- Lectura del lugar (pública para pruebas).
function Location.readPlace(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ''
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    return Geo.place(street, zone)
end

-- Datos actuales, añadidos al mensaje de visibilidad al aparecer.
function Location.snapshot(msg)
    local entity = S.veh
    local bearing = Geo.bearing(GetEntityHeading(entity))
    local main, sub = Location.readPlace(GetEntityCoords(entity))
    sent = { sector = Geo.sector(bearing, nil, cfg.hysteresis), bearing = bearing, main = main, sub = sub }
    msg.sector, msg.bearing = sent.sector, math.floor(bearing + 0.5)
    msg.main, msg.sub = main, sub
    return msg
end

CreateThread(function()
    local nextPlace = 0
    while true do
        if not S.locVisible or S.veh == 0 then
            Wait(250)
        else
            local now = GetGameTimer()
            local entity = S.veh

            local bearing = Geo.bearing(GetEntityHeading(entity))
            local sector = Geo.sector(bearing, sent.sector, cfg.hysteresis)
            if sector ~= sent.sector or not sent.bearing or Geo.angularDiff(bearing, sent.bearing) >= 3 then
                sent.sector, sent.bearing = sector, bearing
                NUI.send({ t = 'location', sector = sector, bearing = math.floor(bearing + 0.5) })
            end

            if now >= nextPlace then
                nextPlace = now + cfg.placeRate
                local main, sub = Location.readPlace(GetEntityCoords(entity))
                if main ~= sent.main or sub ~= sent.sub then
                    sent.main, sent.sub = main, sub
                    NUI.send({ t = 'location', main = main, sub = sub })
                end
            end
            Wait(cfg.headingRate)
        end
    end
end)

CarHud.Location = Location
