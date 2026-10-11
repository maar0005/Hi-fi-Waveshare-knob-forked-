sub init()
    artInit(true)
end sub

sub artInit(readonly as boolean)
    m.readonly = readonly
    m.top.backgroundColor = "0x101012FF"
    m.layer = m.top.FindNode("artLayer")
    m.strip = m.top.FindNode("strip")
    m.metadata = m.top.FindNode("metadata")
    m.client = m.top.FindNode("network")
    m.top.client = m.client
    m.client.readonly = readonly
    m.client.UnobserveField("snapshot")
    m.client.ObserveField("snapshot", "onSnapshot")
    m.artKey = ""
    m.artGeneration = 0
    m.shown = invalid
    m.loading = invalid
    ' Explicit FHD design space; Roku scales the scene for HD displays.
    m.viewport = ArtViewport(1920, 1080, readonly)
    m.strip.translation = [0, m.viewport.height]
    m.strip.width = 1920
    m.strip.height = 36
    m.strip.visible = not readonly
    m.metadata.translation = [30, m.viewport.height + 3]
    m.metadata.width = 1860
    m.metadata.height = 30
    if readonly then m.metadata.translation = [30, 1020]
end sub

sub configure()
    if m.top.settings = invalid then return
    m.client.settings = m.top.settings
    if m.client.state <> "run"
        m.client.control = "RUN"
    else
        m.client.request = { kind: "configure", bridge: m.top.settings.bridge, zone: m.top.settings.zone }
    end if
end sub

sub onSnapshot()
    m.snapshot = m.client.snapshot
    if m.snapshot = invalid then return
    text = m.snapshot.notice
    p = m.snapshot.playing
    if text = "" and p <> invalid and not m.readonly
        text = TextField(p, "line1") + "  ·  " + TextField(p, "line2")
    end if
    m.metadata.text = text
    m.metadata.visible = text <> ""
    identity = ArtIdentity(m.snapshot)
    if p = invalid or TextField(p, "image_key") = ""
        clearArt()
    else if identity <> m.artKey
        m.artKey = identity
        loadArt(m.snapshot)
    end if
    if not m.readonly then updateController()
end sub

sub clearArt()
    if m.loading <> invalid then m.layer.RemoveChild(m.loading)
    if m.shown <> invalid then m.layer.RemoveChild(m.shown)
    m.loading = invalid
    m.shown = invalid
    m.artKey = ""
end sub

sub loadArt(state as object)
    if m.loading <> invalid then m.layer.RemoveChild(m.loading)
    ' Never leave artwork from another room behind while its replacement loads.
    if m.shown <> invalid
        if m.shown.artZone <> state.zone or m.shown.artSession <> state.session
            m.layer.RemoveChild(m.shown)
            m.shown = invalid
        end if
    end if
    poster = CreateObject("roSGNode", "Poster")
    m.artGeneration++
    poster.AddFields({ artZone: state.zone, artSession: state.session, artIdentity: m.artKey, artGeneration: m.artGeneration })
    poster.width = m.viewport.width
    poster.height = m.viewport.height
    poster.loadWidth = m.viewport.width
    poster.loadHeight = m.viewport.height
    ' Server already composed the crop. Fit preserves it without another zoom.
    poster.loadDisplayMode = "scaleToFit"
    poster.visible = false
    poster.ObserveField("loadStatus", "artLoaded")
    m.layer.AppendChild(poster)
    m.loading = poster
    poster.uri = state.artPath + "&width=" + m.viewport.width.ToStr() + "&height=" + m.viewport.height.ToStr()
end sub

sub artLoaded(event as object)
    node = event.GetRoSGNode()
    if m.loading = invalid then return
    if node.artGeneration <> m.loading.artGeneration then return
    if node.artIdentity <> m.artKey then return
    if node.loadStatus = "ready"
        if m.shown <> invalid then m.layer.RemoveChild(m.shown)
        node.visible = true
        m.shown = node
        m.loading = invalid
    else if node.loadStatus = "failed"
        m.layer.RemoveChild(node)
        m.loading = invalid
        m.artKey = ""
        m.metadata.text = "Artwork unavailable — retrying"
        m.metadata.visible = true
    end if
end sub

sub updateController()
    ' Read-only base scene has no controller chrome.
end sub
