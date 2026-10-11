sub init()
    m.top.functionName = "runBridge"
end sub

sub runBridge()
    m.port = CreateObject("roMessagePort")
    m.top.ObserveField("request", m.port)
    m.clock = CreateObject("roTimespan")
    m.clock.Mark()
    m.state = NewClientState(m.top.readonly)
    m.pending = {}
    resetLibrary()
    m.sse = invalid
    m.sseReady = false
    m.failures = 0
    m.sseFailures = 0
    m.nextRead = 0
    m.nextZones = 0
    m.nextSse = 0
    m.sseEnabled = SupportsSSE(CreateObject("roDeviceInfo").GetOSVersion().major)
    config = m.top.settings
    if config = invalid then config = { bridge: "", zone: "" }
    ResetClient(m.state, NormalizeBridge(config.bridge), TextField(config, "zone"))
    publish()
    while true
        now = m.clock.TotalMilliseconds()
        msg = Wait(100, m.port)
        if type(msg) = "roSGNodeEvent"
            handleRequest(msg.GetData())
        else if type(msg) = "roUrlEvent"
            handleResponse(msg)
        else if type(msg) = "roSSEvent"
            handleSSE(msg)
        end if
        expireRequests(now)
        if m.state.bridge <> ""
            if now >= m.nextZones and not pendingRole("zones")
                m.nextZones = now + 30000
                startTransfer("zones", "/zones", invalid)
            end if
            if now >= m.nextRead and not pendingRole("playing") and not m.state.pending
                interval = SnapshotInterval(m.sseReady)
                m.nextRead = now + interval
                if HasZone(m.state.zones, m.state.zone)
                    startTransfer("playing", "/now_playing?zone_id=" + escape(m.state.zone), invalid)
                end if
            end if
            if m.sseEnabled and m.sse = invalid and now >= m.nextSse then startSSE()
        end if
        if m.state.online and now - m.state.freshAt > 45000
            m.state.online = false
            m.state.notice = "Connection stale — reconnecting"
            publish()
        end if
    end while
end sub

function escape(value as string) as string
    if m.encode <> invalid then return m.encode(value)
    return CreateObject("roUrlTransfer").Escape(value)
end function

function newTransfer(path as string) as object
    if m.transportFactory <> invalid then return m.transportFactory()
    x = CreateObject("roUrlTransfer")
    x.SetMessagePort(m.port)
    x.SetUrl(m.state.bridge + path)
    x.SetCertificatesFile("common:/certs/ca-bundle.crt")
    x.AddHeader("Accept", "application/json")
    x.RetainBodyOnError(true)
    return x
end function

sub startTransfer(role as string, path as string, body as dynamic, meta = invalid as dynamic)
    x = newTransfer(path)
    entry = { x: x, role: role, session: m.state.session, zone: m.state.zone, started: m.clock.TotalMilliseconds(), meta: meta }
    m.pending[x.GetIdentity().ToStr()] = entry
    if body = invalid
        started = x.AsyncGetToString()
    else
        x.AddHeader("Content-Type", "application/json")
        started = x.AsyncPostFromString(FormatJson(body))
    end if
    if not started
        m.pending.Delete(x.GetIdentity().ToStr())
        failed(entry)
    end if
end sub

function pendingRole(role as string) as boolean
    for each key in m.pending
        if m.pending[key].role = role then return true
    end for
    return false
end function

sub startSSE()
    if not m.sseEnabled then return
    m.sse = newTransfer("/events")
    m.sse.AddHeader("Accept", "text/event-stream")
    if not m.sse.AsyncGetSSEvents()
        m.sse = invalid
        m.sseReady = false
        m.sseFailures++
        m.nextSse = m.clock.TotalMilliseconds() + RetryDelay(m.sseFailures)
    end if
end sub

sub handleResponse(msg as object)
    id = msg.GetSourceIdentity().ToStr()
    if m.sse <> invalid
        if id = m.sse.GetIdentity().ToStr()
            if msg.GetInt() = 1
                retry = m.sse.SSERetry()
                m.sse = invalid
                m.sseReady = false
                m.sseFailures++
                delay = RetryDelay(m.sseFailures)
                if retry > delay then delay = retry
                if delay > 60000 then delay = 60000
                m.nextSse = m.clock.TotalMilliseconds() + delay
                m.nextRead = 0
            end if
            return
        end if
    end if
    if not m.pending.DoesExist(id) then return
    entry = m.pending[id]
    m.pending.Delete(id)
    if entry.session <> m.state.session or entry.zone <> m.state.zone then return
    code = msg.GetResponseCode()
    if code < 200 or code >= 300
        failed(entry)
        return
    end if
    if entry.role = "command"
        m.state.pending = false
        ' HTTP acceptance is not proof of the resulting playback state.
        m.state.uncertain = true
        m.state.notice = "Refreshing after command"
        invalidatePlaying()
        publish()
        return
    end if
    raw = msg.GetString()
    if Len(raw) > 1048576
        failed(entry)
        return
    end if
    body = ParseJson(raw)
    if type(body) <> "roAssociativeArray"
        failed(entry)
        return
    end if
    if entry.role = "library" or entry.role = "libraryCommand"
        libraryResponse(entry, body)
        return
    end if
    if entry.role = "zones"
        if type(body.zones) <> "roArray"
            failed(entry)
            return
        end if
        m.state.zones = body.zones
        m.failures = 0
        if not HasZone(body.zones, m.state.zone)
            m.state.playing = invalid
            m.state.online = false
            m.state.notice = "Saved zone unavailable — repin in settings"
            if m.state.zone = "" then m.state.notice = "Pin a listening zone in settings"
        end if
        m.nextRead = 0
    else if entry.role = "playing"
        if not AcceptPlaying(m.state, entry.session, entry.zone, body, m.clock.TotalMilliseconds())
            failed(entry)
            return
        end if
        m.failures = 0
    end if
    publish()
end sub

sub invalidatePlaying()
    for each key in m.pending.Keys()
        if m.pending[key].role = "playing"
            m.pending[key].x.AsyncCancel()
            m.pending.Delete(key)
        end if
    end for
    m.nextRead = 0
end sub

sub failed(entry as object)
    if entry.role = "library" or entry.role = "libraryCommand"
        libraryFailed(entry)
        return
    end if
    if entry.role = "command"
        m.state.pending = false
        m.state.uncertain = true
        m.state.notice = "Command outcome unknown — checking state"
        invalidatePlaying()
    else
        m.state.online = false
        m.state.notice = "Bridge unavailable — reconnecting"
        m.failures++
        delay = RetryDelay(m.failures)
        m.nextRead = m.clock.TotalMilliseconds() + delay
        m.nextZones = m.nextRead
    end if
    publish()
end sub

sub expireRequests(now as integer)
    for each key in m.pending.Keys()
        entry = m.pending[key]
        if now - entry.started >= 8000
            entry.x.AsyncCancel()
            m.pending.Delete(key)
            failed(entry)
        end if
    end for
end sub

sub handleRequest(req as dynamic)
    if type(req) <> "roAssociativeArray" then return
    if req.kind = "configure"
        for each key in m.pending
            m.pending[key].x.AsyncCancel()
        end for
        m.pending = {}
        resetLibrary()
        if m.sse <> invalid then m.sse.AsyncCancel()
        m.sse = invalid
        m.sseReady = false
        ResetClient(m.state, NormalizeBridge(req.bridge), TextField(req, "zone"))
        m.nextRead = 0
        m.nextZones = 0
        m.nextSse = 0
        m.failures = 0
        publish()
    else if req.kind = "library" or req.kind = "library_play" or req.kind = "library_close"
        requestLibrary(req)
    else if req.kind = "command"
        if req.session <> m.state.session or req.zone <> m.state.zone then return
        if not AllowsCommand(m.state, TextField(req, "action"), m.clock.TotalMilliseconds())
            m.state.notice = "Control unavailable — refreshing state"
            m.nextRead = 0
            publish()
            return
        end if
        m.state.pending = true
        m.state.notice = "Sending command"
        startTransfer("command", "/control", { zone_id: m.state.zone, action: req.action })
        publish()
    else if req.kind = "refresh"
        m.nextRead = 0
        m.nextZones = 0
    end if
end sub

sub publish()
    artPath = ""
    if m.state.playing <> invalid and m.state.bridge <> ""
        ' URL encoding belongs on the Task thread, never the render thread.
        artPath = m.state.bridge + "/now_playing/image?zone_id=" + escape(m.state.zone) + "&k=" + escape(TextField(m.state.playing, "image_key"))
    end if
    allowed = {}
    for each action in ["previous", "play_pause", "next", "vol_down", "vol_up"]
        allowed[action] = AllowsCommand(m.state, action, m.clock.TotalMilliseconds())
    end for
    m.top.snapshot = { allowed: allowed, artPath: artPath, session: m.state.session, bridge: m.state.bridge, zone: m.state.zone, zones: m.state.zones, playing: m.state.playing, online: m.state.online, pending: m.state.pending, uncertain: m.state.uncertain, notice: m.state.notice, freshAt: m.state.freshAt, readonly: m.state.readonly }
end sub

sub handleSSE(msg as object)
    if m.sse = invalid then return
    if msg.GetSourceIdentity() <> m.sse.GetIdentity() then return
    m.sseReady = true
    m.sseFailures = 0
    m.nextRead = 0
end sub
