sub init()
    m.client = m.top.FindNode("network")
    m.top.client = m.client
    m.client.ObserveField("snapshot", "settingsSnapshot")
    m.choices = m.top.FindNode("choices")
    m.choices.ObserveField("buttonSelected", "chooseSetting")
    m.zoneList = m.top.FindNode("zoneList")
    m.zoneList.ObserveField("itemSelected", "zoneChosen")
    m.discoveryGeneration = 0
    m.selectionMode = "zone"
    m.discovery = m.top.FindNode("discovery")
    m.discovery.ObserveField("result", "discoveryResult")
    m.choices.SetFocus(true)
end sub

sub startSettings()
    if m.top.settings = invalid then return
    m.saved = m.top.settings
    m.client.settings = m.saved
    m.client.control = "RUN"
    if m.saved.bridge = "" then findBridges()
end sub

sub settingsSnapshot()
    m.status = m.client.snapshot
    if m.selectionMode = "bridge" and m.zoneList.visible then return
    m.top.FindNode("status").text = SettingsStatus(m.status)
end sub

sub chooseSetting()
    index = m.choices.buttonSelected
    if index = 0
        findBridges()
    else if index = 1
        bridgeDialog()
    else if index = 2
        zoneDialog()
    else
        m.top.done = true
    end if
end sub

sub bridgeDialog()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Music bridge address"
    dialog.message = ["Enter a host or IP address. Default port: 8088."]
    dialog.text = m.saved.bridge
    dialog.buttons = ["Connect", "Cancel"]
    dialog.ObserveField("buttonSelected", "bridgeChosen")
    dialog.ObserveField("wasClosed", "bridgeDismissed")
    m.top.dialog = dialog
end sub

sub bridgeChosen()
    dialog = m.top.dialog
    if dialog.buttonSelected = 0
        bridge = NormalizeBridge(dialog.text)
        if bridge = ""
            dialog.title = "Check the bridge address"
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
    m.selectionMode = "zone"
    if m.status = invalid then return
    m.zoneOptions = []
    content = settingsContent()
    for each zone in m.status.zones
        id = TextField(zone, "zone_id")
        if id <> ""
            m.zoneOptions.Push(id)
            item = content.CreateChild("ContentNode")
            item.title = TextField(zone, "zone_name") + " · " + TextField(zone, "source")
        end if
    end for
    if m.zoneOptions.Count() = 0
        m.top.FindNode("status").text = "No zones found. Check your music bridge address."
        return
    end if
    m.top.FindNode("status").visible = false
    m.top.FindNode("heading").text = "Pick a zone"
    m.zoneList.content = content
    m.zoneList.visible = true
    m.choices.visible = false
    m.zoneList.SetFocus(true)
end sub

sub zoneChosen()
    index = m.zoneList.itemSelected
    if m.selectionMode = "bridge"
        if index < m.bridgeOptions.Count()
            bridge = m.bridgeOptions[index].bridge
            if bridge <> m.saved.bridge then m.saved.zone = ""
            m.saved.bridge = bridge
            SaveSettings(m.top.profile, bridge, m.saved.zone)
            m.client.request = {kind: "configure", bridge: bridge, zone: m.saved.zone}
            closeZones()
        else
            closeZones()
            bridgeDialog()
        end if
        return
    end if
    if index < m.zoneOptions.Count()
        m.saved.zone = m.zoneOptions[index]
        SaveSettings(m.top.profile, m.saved.bridge, m.saved.zone)
        m.client.request = { kind: "configure", bridge: m.saved.bridge, zone: m.saved.zone }
    end if
    closeZones()
end sub

sub closeZones()
    m.discoveryGeneration++
    m.discovery.control = "STOP"
    m.top.FindNode("status").visible = true
    m.top.FindNode("heading").text = "Settings"
    m.zoneList.visible = false
    m.choices.visible = true
    m.choices.SetFocus(true)
end sub

function handleSettingsKey(key as string, press as boolean) as boolean
    if press and key = "back"
        if m.zoneList.visible
            closeZones()
            return true
        end if
        m.discoveryGeneration++
        m.discovery.control = "STOP"
        m.top.done = true
        return true
    end if
    return false
end function

sub bridgeDismissed()
    m.choices.SetFocus(true)
end sub

sub findBridges()
    m.discovery.control = "STOP"
    m.discoveryGeneration++
    m.discovery.generation = m.discoveryGeneration
    m.selectionMode = "bridge"
    m.bridgeOptions = []
    m.top.FindNode("heading").text = "Find a music bridge"
    m.top.FindNode("status").visible = true
    m.top.FindNode("status").text = "Looking for bridges on your network…"
    m.choices.visible = false
    content = settingsContent()
    content.CreateChild("ContentNode").title = "Enter an address"
    m.zoneList.content = content
    m.zoneList.visible = true
    m.zoneList.SetFocus(true)
    m.discovery.control = "RUN"
end sub

sub discoveryResult()
    result = m.discovery.result
    if result = invalid then return
    if result.generation <> m.discoveryGeneration or m.selectionMode <> "bridge" then return
    m.bridgeOptions = result.bridges
    content = settingsContent()
    for each bridge in m.bridgeOptions
        content.CreateChild("ContentNode").title = bridge.name + " · " + bridge.bridge
    end for
    content.CreateChild("ContentNode").title = "Enter an address"
    m.zoneList.content = content
    m.zoneList.jumpToItem = 0
    m.top.FindNode("status").text = result.notice
end sub

function settingsContent() as object
    if m.contentFactory <> invalid then return m.contentFactory()
    return CreateObject("roSGNode", "ContentNode")
end function
