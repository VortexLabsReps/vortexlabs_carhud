-- Arranque del servidor: resumen de la configuración detectada.
CreateThread(function()
    Wait(0)
    print(('[vortexlabs_carhud] v%s · %s'):format(GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?',
        CarHud.T('framework_detected', CarHud.Framework.name, Config.Fuel.provider, Config.Seatbelt.mode)))
end)
