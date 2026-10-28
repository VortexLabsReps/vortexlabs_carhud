-- /carhudadmin: los cambios sobreviven a un reinicio del servidor; lo inválido
-- del archivo se descarta sin romper el arranque.
local F = dofile(FD_ROOT .. '/dev/fivem.lua')
F.files['data/nitro.json'] = '{}'
F.files['data/admin.json'] = json.encode({
    ['Seatbelt.ejection.minSpeed'] = 110,
    ['Nitro.power'] = 3.5,
    ['Seatbelt.ejection.categories'] = { 'car', 'heli' },
    ['Seatbelt.ejection.verticalForce'] = 99,      -- fuera de límites
    ['Engine.key'] = 'NOPE',                        -- tecla inválida
    ['Config.Engine.authorize'] = 'none',           -- no editable
    ['Seatbelt.ejection.ragdoll'] = 4000,           -- igual al predeterminado
})
F.load(F.SHARED)
F.load(F.SERVER)

F.section('Reinicio con data/admin.json')
F.eq(Config.Seatbelt.ejection.minSpeed, 110, 'valor guardado aplicado al arrancar')
F.eq(Config.Nitro.power, 3.5, 'potencia del nitro guardada')
F.eq(table.concat(Config.Seatbelt.ejection.categories, ','), 'car,heli', 'categorías guardadas')
F.eq(Config.Seatbelt.ejection.verticalForce, 2.5, 'valor fuera de límites descartado (predeterminado)')
F.eq(Config.Engine.key, 'G', 'tecla inválida descartada')
F.eq(Config.Engine.authorize, 'auto', 'los permisos de llaves no se pueden alterar desde el archivo')
local state = GlobalState.fcarhud_admin
F.ok(state.values['Seatbelt.ejection.minSpeed'] == 110 and state.values['Seatbelt.ejection.ragdoll'] == nil and state.values['Engine.key'] == nil, 'se difunden solo los cambios válidos')

F.finish()
