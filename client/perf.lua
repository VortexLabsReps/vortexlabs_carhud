-- Medición propia: /carhud perf [segundos]. Complementa a resmon (que sigue
-- siendo la referencia): suma el tiempo de los bucles Lua de este recurso y
-- pide a la NUI su coste por fotograma animado.
local Perf = { active = false }

-- El cliente de FiveM no expone la librería 'os': sin reloj de alta resolución
-- no se mide el coste Lua (resmon lo da) y solo se informa de la NUI.
local clock = nil
local osLib = rawget(_G, 'os')
if type(osLib) == 'table' then
    if osLib.nanotime then
        clock = function() return osLib.nanotime() / 1e6 end
        Perf.timer = 'os.nanotime'
    elseif osLib.microtime then
        clock = function() return osLib.microtime() / 1e3 end
        Perf.timer = 'os.microtime'
    elseif osLib.clock then
        clock = function() return osLib.clock() * 1000 end
        Perf.timer = 'os.clock'
    end
end

local function add(cost)
    Perf.total = Perf.total + cost
    if cost > Perf.peak then Perf.peak = cost end
end

function Perf.begin()
    if Perf.active and clock then return clock() end
    return nil
end

function Perf.finish(started)
    if started then add(clock() - started) end
end

function Perf.start(seconds)
    if Perf.active then return end
    seconds = math.max(3, math.min(60, tonumber(seconds) or 10))
    Perf.active, Perf.total, Perf.peak = true, 0, 0
    local frames, sent = GetFrameCount(), CarHud.NUI.sent
    if clock then CarHud.Frame.cost = function(ms) add(ms) end end
    print(CarHud.T('perf_start', seconds))
    CarHud.NUI.send({ t = 'perf', ms = seconds * 1000 })
    SetTimeout(seconds * 1000, function()
        Perf.active = false
        CarHud.Frame.cost = nil
        local elapsedFrames = math.max(1, GetFrameCount() - frames)
        local rate = (CarHud.NUI.sent - sent) / seconds
        if clock then
            print(CarHud.T('perf_result', Perf.total / elapsedFrames, Perf.peak, rate, elapsedFrames) .. (' [%s]'):format(Perf.timer))
        else
            print(CarHud.T('perf_result_noclock', rate, elapsedFrames))
        end
    end)
end

-- El bucle por fotograma usa el mismo reloj (milisegundos).
CarHud.Frame.now = clock

RegisterNUICallback('perf', function(data, cb)
    if type(data) == 'table' then
        print(CarHud.T('perf_nui', tonumber(data.avg) or 0, tonumber(data.peak) or 0, tonumber(data.frames) or 0, tonumber(data.ticks) or 0))
    end
    cb({})
end)

CarHud.Perf = Perf
