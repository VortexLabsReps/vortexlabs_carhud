-- Traducciones: una sola fuente por idioma, locales/<idioma>.json, con dos
-- secciones: "game" (teclas, comandos, consola, avisos de Lua) y "ui" (interfaz;
-- se envía a la NUI al iniciarse). Las claves que falten caen al inglés.
local Locale = { lang = 'en', game = {}, ui = {}, fallback = { game = {}, ui = {} } }

local function load(lang)
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print(('[vortexlabs_carhud] locales/%s.json: invalid JSON'):format(lang))
        return nil
    end
    return { game = type(data.game) == 'table' and data.game or {}, ui = type(data.ui) == 'table' and data.ui or {} }
end

local function init()
    local en = load('en') or { game = {}, ui = {} }
    local lang = type(Config.Locale) == 'string' and Config.Locale:lower() or 'en'
    local dict = lang == 'en' and en or load(lang)
    if not dict then
        print(('[vortexlabs_carhud] Locale "%s" not found in locales/; using English.'):format(tostring(Config.Locale)))
        lang, dict = 'en', en
    end
    Locale.lang, Locale.game, Locale.ui = lang, dict.game, dict.ui
    Locale.fallback = en
end
init()

function CarHud.T(key, ...)
    local text = Locale.game[key] or Locale.fallback.game[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

CarHud.Locale = Locale
