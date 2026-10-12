sub Main()
    while true
        settings = LoadSettings("controller")
        if settings.bridge = "" or settings.zone = "" then RunHiPhi("SettingsScene", "controller")
        if not RunController() then exit while
        RunHiPhi("SettingsScene", "controller")
    end while
end sub

function RunController() as boolean
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("ControllerScene")
    scene.profile = "controller"
    scene.settings = LoadSettings("controller")
    scene.ObserveField("openSettings", port)
    screen.Show()
    scene.SetFocus(true)
    settingsRequested = false
    while true
        msg = Wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.IsScreenClosed() then exit while
        else if type(msg) = "roSGNodeEvent"
            if msg.GetField() = "openSettings"
                settingsRequested = true
                screen.Close()
                exit while
            end if
        end if
    end while
    scene.client.control = "STOP"
    return settingsRequested
end function
