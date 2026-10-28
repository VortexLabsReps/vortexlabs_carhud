-- Exporta el esquema real de /carhudadmin (shared/admin.lua) para la vista previa
-- y las pruebas de la NUI: node run.js dump_admin.lua > ../preview/admin-fixture.json
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.load(F.SHARED)
local keys = {}
for key in pairs(CarHud.Admin.KEYS) do keys[#keys + 1] = key end
table.sort(keys)
F.realPrint(json.encode({ fields = CarHud.Admin.FIELDS, keys = keys, defaults = CarHud.Admin.defaults() }))
