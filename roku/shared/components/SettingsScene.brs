sub init()
    m.client = m.top.FindNode("network")
    m.top.client = m.client
    m.client.ObserveField("snapshot", "settingsSnapshot")
    m.choices = m.top.FindNode("choices")
    m.choices.ObserveField("buttonSelected", "chooseSetting")
    m.zoneList = m.top.FindNode("zoneList")
    m.zoneList.ObserveField("itemSelected", "zoneChosen")
    m.choices.SetFocus(true)
end sub

sub startSettings()
    if m.top.settings = invalid then return
    m.saved = m.top.settings
    m.client.settings = m.saved
    m.client.control = "RUN"
    if m.saved.bridge = "" then bridgeDialog()
end sub

sub settingsSnapshot()
    m.status = m.client.snapshot
    m.top.FindNode("status").text = SettingsStatus(m.status)
end sub

sub chooseSetting()
    index = m.choices.buttonSelected
    if index = 0
        bridgeDialog()
    else if index = 1
        zoneDialog()
    else
        m.top.done = true
    end if
end sub

sub bridgeDialog()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "UHC bridge address"
    dialog.message = ["Enter a host or IP address. Default port: 8088."]
    dialog.text = m.saved.bridge
    dialog.buttons = ["Connect", "Cancel"]
    dialog.ObserveField("buttonSelected", "bridgeChosen")
    m.top.dialog = dialog
end sub

sub bridgeChosen()
    dialog = m.top.dialog
    if dialog.buttonSelected = 0
        bridge = NormalizeBridge(dialog.text)
        if bridge = ""
            dialog.title = "Enter a host or IP, optionally :port"
            return
        end if
        if bridge <> m.saved.bridge then m.saved.zone = ""
        m.saved.bridge = bridge
        SaveSettings(m.top.profile, bridge, m.saved.zone)
        m.client.request = { kind: "configure", bridge: bridge, zone: m.saved.zone }
    end if
    dialog.close = true
    m.choices.SetFocus(true)
end sub

sub zoneDialog()
    if m.status = invalid then return
    m.zoneOptions = []
    content = CreateObject("roSGNode", "ContentNode")
    for each zone in m.status.zones
        id = TextField(zone, "zone_id")
        if id <> ""
            m.zoneOptions.Push(id)
            item = content.CreateChild("ContentNode")
            item.title = TextField(zone, "zone_name") + " · " + TextField(zone, "source")
        end if
    end for
    if m.zoneOptions.Count() = 0
        m.top.FindNode("status").text = "No zones available. Check the bridge address and connection."
        return
    end if
    m.zoneList.content = content
    m.zoneList.visible = true
    m.choices.visible = false
    m.zoneList.SetFocus(true)
end sub

sub zoneChosen()
    index = m.zoneList.itemSelected
    if index < m.zoneOptions.Count()
        m.saved.zone = m.zoneOptions[index]
        SaveSettings(m.top.profile, m.saved.bridge, m.saved.zone)
        m.client.request = { kind: "configure", bridge: m.saved.bridge, zone: m.saved.zone }
    end if
    closeZones()
end sub

sub closeZones()
    m.zoneList.visible = false
    m.choices.visible = true
    m.choices.SetFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        if m.zoneList.visible
            closeZones()
            return true
        end if
        m.top.done = true
        return true
    end if
    return false
end function
