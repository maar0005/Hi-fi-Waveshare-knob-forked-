function LoadSettings(profile as string) as object
    reg = SettingsRegistry(profile)
    return { bridge: NormalizeBridge(reg.Read("bridge")), zone: reg.Read("zone") }
end function

sub SaveSettings(profile as string, bridge as string, zone as string)
    reg = SettingsRegistry(profile)
    reg.Write("bridge", bridge)
    reg.Write("zone", zone)
    reg.Flush()
end sub

sub RunHiPhi(sceneName as string, profile as string)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene(sceneName)
    scene.profile = profile
    scene.settings = LoadSettings(profile)
    scene.ObserveField("done", port)
    screen.Show()
    if sceneName = "SettingsScene"
        if scene.dialog = invalid
            if scene.FindNode("zoneList").visible
                scene.FindNode("zoneList").SetFocus(true)
            else
                scene.FindNode("choices").SetFocus(true)
            end if
        end if
    else
        scene.SetFocus(true)
    end if
    while true
        msg = Wait(0, port)
        if type(msg) = "roSGScreenEvent"
            if msg.IsScreenClosed() then exit while
        else if type(msg) = "roSGNodeEvent"
            if msg.GetField() = "done" and msg.GetData() = true
                screen.Close()
                exit while
            end if
        end if
    end while
    scene.client.control = "STOP"
end sub

function SettingsRegistry(profile as string) as object
    if m.registryFactory <> invalid then return m.registryFactory(profile)
    return CreateObject("roRegistrySection", "hiphi-" + profile)
end function

function SettingsStatus(state as dynamic) as string
    if type(state) <> "roAssociativeArray" then return "Connecting"
    connection = TextField(state, "notice")
    if connection = ""
        connection = "Connecting"
        if TrueField(state, "online") then connection = "Connected"
    end if
    room = "Not selected"
    zoneId = TextField(state, "zone")
    if zoneId <> ""
        room = "Selected zone unavailable"
        if type(state.zones) = "roArray"
            for each zone in state.zones
                if TextField(zone, "zone_id") = zoneId
                    room = TextField(zone, "zone_name")
                    if room = "" then room = "Selected zone"
                end if
            end for
        end if
    end if
    return TextField(state, "bridge") + Chr(10) + connection + Chr(10) + "Zone: " + room
end function
