-- Contabilidad del nitro, sin natives (se prueba fuera del juego).
-- Todas las cantidades se validan aquí; ningún valor llega del cliente.
local Util = CarHud.Util
local Store = {}
Store.__index = Store

-- clock: función que devuelve milisegundos (GetGameTimer en el servidor).
function Store.new(cfg, clock)
    return setmetatable({ cfg = cfg, clock = clock, data = {}, active = {}, cooldown = {}, dirty = false }, Store)
end

local function capacity(self, value)
    return Util.clamp(Util.number(value) or self.cfg.defaultCapacity, 1, self.cfg.maxCapacity)
end

function Store:get(plate)
    return plate and self.data[plate] or nil
end

function Store:equip(plate, cap, amount)
    if not plate then return nil, 'plate' end
    cap = capacity(self, cap)
    local amt = Util.clamp(Util.number(amount) or cap, 0, cap)
    self.data[plate] = { cap = cap, amt = amt }
    self.dirty = true
    return self.data[plate]
end

-- amount nil = llenar. Las cantidades negativas se rechazan.
function Store:refill(plate, amount)
    local entry = self:get(plate)
    if not entry then return nil, 'none' end
    local add = Util.number(amount)
    if add ~= nil and add < 0 then return nil, 'amount' end
    self:consume(plate)
    entry.amt = Util.clamp(add and entry.amt + add or entry.cap, 0, entry.cap)
    self.dirty = true
    return entry
end

function Store:remove(plate)
    if not self:get(plate) then return false end
    self.active[plate] = nil
    self.data[plate] = nil
    self.dirty = true
    return true
end

function Store:isActive(plate)
    return self.active[plate] ~= nil
end

function Store:start(plate, owner)
    local entry = self:get(plate)
    if not entry then return false, 'none' end
    if self.active[plate] then return false, 'active' end
    local now = self.clock()
    if self.cooldown[plate] and now - self.cooldown[plate] < self.cfg.cooldown then return false, 'cooldown' end
    if entry.amt < self.cfg.minToActivate then return false, 'empty' end
    self.active[plate] = { owner = owner, last = now }
    return true
end

-- Descuenta el consumo transcurrido. Devuelve la carga y si sigue activo.
function Store:consume(plate)
    local entry, run = self:get(plate), self.active[plate]
    if not entry or not run then return entry and entry.amt or 0, false end
    local now = self.clock()
    local used = (now - run.last) / 1000 * self.cfg.consumption
    run.last = now
    if used > 0 then
        entry.amt = math.max(0, entry.amt - used)
        self.dirty = true
    end
    if entry.amt <= 0 then
        self:stop(plate)
        return 0, false
    end
    return entry.amt, true
end

function Store:stop(plate)
    if not self.active[plate] then return false end
    local run = self.active[plate]
    self.active[plate] = nil
    local entry = self:get(plate)
    if entry then
        local used = (self.clock() - run.last) / 1000 * self.cfg.consumption
        if used > 0 then entry.amt = math.max(0, entry.amt - used) end
        self.dirty = true
    end
    self.cooldown[plate] = self.clock()
    return true
end

function Store:activeBy(owner)
    local list = {}
    for plate, run in pairs(self.active) do
        if run.owner == owner then list[#list + 1] = plate end
    end
    return list
end

function Store:serialize()
    local out = {}
    for plate, entry in pairs(self.data) do
        out[plate] = { cap = Util.round(entry.cap, 2), amt = Util.round(entry.amt, 2) }
    end
    return out
end

-- Carga datos guardados descartando entradas inválidas.
function Store:load(saved)
    self.data = {}
    if type(saved) ~= 'table' then return 0 end
    local count = 0
    for plate, entry in pairs(saved) do
        local key = Util.normalizePlate(plate)
        if key and type(entry) == 'table' and Util.number(entry.cap) then
            local cap = capacity(self, entry.cap)
            self.data[key] = { cap = cap, amt = Util.clamp(Util.number(entry.amt) or 0, 0, cap) }
            count = count + 1
        end
    end
    return count
end

CarHud.NitroStore = Store
