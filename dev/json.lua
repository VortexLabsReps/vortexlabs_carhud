-- JSON mínimo para el banco de pruebas (FiveM ya trae 'json'). Objetos, listas,
-- cadenas, números, booleanos y null; suficiente para data/vehicles.json.
local json = {}

local function esc(s)
    return s:gsub('[%c"\\]', function(c)
        local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return map[c] or ('\\u%04x'):format(c:byte())
    end)
end

local function isList(t)
    local n = 0
    for k in pairs(t) do
        if math.type(k) ~= 'integer' or k < 1 then return false end
        n = n + 1
    end
    return n == #t
end

function json.encode(v)
    local t = type(v)
    if v == nil then return 'null' end
    if t == 'boolean' then return tostring(v) end
    if t == 'number' then return (math.type(v) == 'integer') and tostring(v) or ('%.17g'):format(v) end
    if t == 'string' then return '"' .. esc(v) .. '"' end
    if t == 'table' then
        local parts = {}
        if next(v) ~= nil and isList(v) then
            for i = 1, #v do parts[i] = json.encode(v[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do parts[#parts + 1] = json.encode(k) .. ':' .. json.encode(v[k]) end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    error('json: tipo no soportado ' .. t)
end

function json.decode(s)
    local i = 1
    local function ws() i = s:find('[^%s]', i) or #s + 1 end
    local value
    local function str()
        local out, j = {}, i + 1
        while true do
            local c = s:sub(j, j)
            if c == '"' then i = j + 1 return table.concat(out) end
            if c == '\\' then
                local n = s:sub(j + 1, j + 1)
                local map = { n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16)) j = j + 6
                else out[#out + 1] = map[n] j = j + 2 end
            elseif c == '' then error('json: cadena sin cerrar')
            else out[#out + 1] = c j = j + 1 end
        end
    end
    function value()
        ws()
        local c = s:sub(i, i)
        if c == '{' then
            local o = {}
            i = i + 1 ws()
            if s:sub(i, i) == '}' then i = i + 1 return o end
            while true do
                ws()
                local k = str()
                ws() i = i + 1          -- ':'
                o[k] = value()
                ws()
                local d = s:sub(i, i) i = i + 1
                if d == '}' then return o end
            end
        elseif c == '[' then
            local a = {}
            i = i + 1 ws()
            if s:sub(i, i) == ']' then i = i + 1 return a end
            while true do
                a[#a + 1] = value()
                ws()
                local d = s:sub(i, i) i = i + 1
                if d == ']' then return a end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4 return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5 return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4 return nil
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i)
            i = i + #num
            return tonumber(num)
        end
    end
    return value()
end

return json
