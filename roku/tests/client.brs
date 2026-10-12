sub Main()
    m.testFailures = 0
    m.count = 0
    empty = NewClientState(true)
    ResetClient(empty, "", "")
    check(empty.notice = "Connect to your music bridge in Settings", "unconfigured screensaver names settings recovery")
    s = NewClientState(false)
    ResetClient(s, "http://bridge:8088", "a")
    s.zones = [{zone_id: "a"}, {zone_id: "b"}]
    p = {zone_id: "a", is_playing: true, is_pause_allowed: true, is_play_allowed: true, is_next_allowed: true, is_previous_allowed: false, volume: -30, volume_type: "db", image_key: "cover"}
    check(AcceptPlaying(s, s.session, "a", p, 100), "accept authoritative selected-zone snapshot")
    check(AllowsCommand(s, "play_pause", 100), "pause capability")
    check(not AllowsCommand(s, "previous", 100), "previous unavailable")
    p.is_next_allowed = "true"
    check(not AllowsCommand(s, "next", 100), "malformed capability fails closed")
    p.is_next_allowed = true
    check(not AllowsCommand(s, "delete", 100), "unknown command rejected")
    check(AllowsCommand(s, "vol_up", 100), "db volume")
    p.volume_type = "fixed"
    check(not AllowsCommand(s, "vol_up", 100), "fixed volume rejected")
    p.volume_type = "mystery"
    check(not AllowsCommand(s, "vol_up", 100), "unknown volume fails closed")
    p.volume_type = "number"
    p.volume = invalid
    check(not AllowsCommand(s, "vol_down", 100), "missing volume rejected")
    check(not AllowsCommand(s, "next", 10200), "stale snapshot cannot command")
    s.pending = true
    check(not AllowsCommand(s, "next", 100), "one command in flight")
    s.uncertain = true
    check(AcceptPlaying(s, s.session, "a", p, 200), "snapshot can refresh during POST")
    check(s.uncertain, "snapshot cannot unlock a pending POST")
    s.pending = false
    check(AcceptPlaying(s, s.session, "a", p, 300), "fresh read reconciles uncertainty")
    check(not s.uncertain, "uncertainty cleared only by authoritative read")
    old = s.session
    ResetClient(s, "http://bridge:8088", "b")
    s.zones = [{zone_id: "a"}, {zone_id: "b"}]
    check(not AcceptPlaying(s, old, "a", p, 400), "late previous-zone response rejected")
    check(s.zone = "b" and s.playing = invalid, "no stale art or silent zone redirect")
    check(not AcceptPlaying(s, s.session, "b", p, 400), "mismatched body zone rejected")
    p.zone_id = "b"
    p.is_playing = invalid
    check(not AcceptPlaying(s, s.session, "b", p, 400), "malformed playing state rejected")
    p.is_playing = true
    s.zones = []
    check(not AcceptPlaying(s, s.session, "b", p, 400), "removed saved zone fails closed")
    saver = NewClientState(true)
    ResetClient(saver, "http://bridge:8088", "b")
    saver.zones = [{zone_id: "b"}]
    check(AcceptPlaying(saver, saver.session, "b", p, 100), "screensaver reads shared snapshots")
    check(not AllowsCommand(saver, "next", 100), "screensaver refuses commands")
    check(ArtViewport(1920, 1080, true).height = 1080, "screensaver reclaims full height")
    check(ArtViewport(1920, 1080, false).height = 1044, "controller reserves only tiny strip")
    check(not SupportsSSE("15") and SupportsSSE("16") and SupportsSSE("17"), "OS 16 SSE boundary")
    check(not SupportsSSE(invalid), "unknown OS falls back to polling")
    check(RetryDelay(0) = 1000 and RetryDelay(20) = 60000, "bounded reconnect backoff")
    check(NormalizeBridge(" http://192.168.1.2:8088/ ") = "http://192.168.1.2:8088", "normalize bridge root")
    check(NormalizeBridge("http://user:secret@host") = "", "credentials rejected")
    check(NormalizeBridge("http://host/path") = "", "UI URL not bridge root")
    check(NormalizeBridge("file:///tmp/x") = "", "non HTTP scheme rejected")
    check(NormalizeBridge("192.168.1.2") = "http://192.168.1.2:8088", "bare IP supplies HTTP and default UHC port")
    check(NormalizeBridge(" bridge.local/ ") = "http://bridge.local:8088", "bare hostname trims and accepts trailing slash")
    check(NormalizeBridge("bridge.local:9000") = "http://bridge.local:9000", "bare hostname preserves explicit port")
    check(NormalizeBridge("http://bridge.local") = "http://bridge.local:8088", "explicit HTTP without port uses 8088")
    check(NormalizeBridge("HTTPS://bridge.local") = "https://bridge.local:8088", "HTTPS preserved with default port and normalized scheme")
    check(NormalizeBridge("https://bridge.local:443") = "https://bridge.local:443", "explicit HTTPS port preserved")
    check(NormalizeBridge("bridge.local:0") = "" and NormalizeBridge("bridge.local:65536") = "", "invalid explicit ports rejected")
    check(NormalizeBridge("bridge.local/path") = "" and NormalizeBridge("user:secret@bridge.local") = "", "bare paths and credentials still rejected")
    networkTests()
    transferTests()
    settingsTests()
    if m.testFailures = 0 then print "PASS all client tests: "; m.count
end sub

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.testFailures++
        print "FAIL: "; label
    end if
end sub

sub networkTests()
    m.clock = { TotalMilliseconds: function() as integer
        return 1000
    end function }
    m.encode = function(value as string) as string
        return value
    end function
    m.top = {}
    m.state = NewClientState(false)
    ResetClient(m.state, "http://bridge:8088", "a")
    m.state.zones = [{zone_id: "a"}]
    body = {zone_id: "a", is_playing: true, is_next_allowed: true}
    AcceptPlaying(m.state, m.state.session, "a", body, 900)
    m.pending = {}
    m.sse = invalid
    m.failures = 0
    m.state.pending = true
    failed({role: "command"})
    check(m.state.uncertain and not m.state.pending, "failed POST locks commands until reconciliation")
    check(m.pending.Count() = 0, "failed POST is not retried")
    check(not AllowsCommand(m.state, "next", 1000), "unknown POST outcome refuses another command")
    entry = {role: "playing", session: m.state.session, zone: "a", x: {AsyncCancel: sub()
    end sub}}
    m.pending["12"] = entry
    m.pending["13"] = {role: "command", session: m.state.session, zone: "a", x: {AsyncCancel: sub()
    end sub}}
    invalidatePlaying()
    check(not m.pending.DoesExist("12") and m.pending.DoesExist("13"), "post-command invalidation cancels GET not POST")
    m.pending = {}
    handleResponse(fakeResponse("404", 200, "{}"))
    check(m.state.zone = "a", "unknown transfer event ignored")
    m.pending["12"] = {role: "playing", session: m.state.session - 1, zone: "a"}
    handleResponse(fakeResponse("12", 200, FormatJson(body)))
    check(m.state.uncertain, "late pre-command/session response cannot unlock commands")
    m.pending["12"] = {role: "playing", session: m.state.session, zone: "a"}
    handleResponse(fakeResponse("12", 200, "broken json"))
    check(not m.state.online, "malformed HTTP body marks offline")
    m.pending["12"] = {role: "playing", session: m.state.session, zone: "a"}
    handleResponse(fakeResponse("12", 200, FormatJson(body)))
    check(m.state.online and not m.state.uncertain, "fresh successful snapshot recovers connection")
    m.pending["12"] = {role: "zones", session: m.state.session, zone: "a"}
    handleResponse(fakeResponse("12", 200, "{""zones"": []}"))
    check(m.state.zone = "a" and m.state.playing = invalid, "missing saved zone does not choose another room")
end sub

function fakeResponse(id as string, code as integer, body as string) as object
    return { id: id, code: code, body: body,
        GetSourceIdentity: function() as integer
            return Val(m.id)
        end function,
        GetInt: function() as integer
            return 1
        end function,
        GetResponseCode: function() as integer
            return m.code
        end function,
        GetString: function() as string
            return m.body
        end function }
end function

function fakeTransfer() as object
    return { id: 51, postCount: 0, getCount: 0, cancelCount: 0, sseCount: 0, started: true, retry: 0,
        GetIdentity: function() as integer
            return m.id
        end function,
        AddHeader: sub(name as string, value as string)
        end sub,
        AsyncPostFromString: function(body as string) as boolean
            m.postCount++
            m.body = body
            return m.started
        end function,
        AsyncGetToString: function() as boolean
            m.getCount++
            return m.started
        end function,
        AsyncCancel: sub()
            m.cancelCount++
        end sub,
        AsyncGetSSEvents: function() as boolean
            m.sseCount++
            return m.started
        end function,
        SSERetry: function() as integer
            return m.retry
        end function }
end function

sub transferTests()
    m.state = NewClientState(false)
    ResetClient(m.state, "http://bridge:8088", "a")
    m.state.zones = [{zone_id: "a"}]
    playing = {zone_id: "a", is_playing: true, is_next_allowed: true, is_pause_allowed: true}
    AcceptPlaying(m.state, m.state.session, "a", playing, 1000)
    m.pending = {}
    m.testX = fakeTransfer()
    m.transportFactory = function() as object
        return m.testX
    end function
    handleRequest({kind: "command", action: "next", session: m.state.session - 1, zone: "a"})
    check(m.testX.postCount = 0, "stale queued input never sends a POST")
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "wrong"})
    check(m.testX.postCount = 0, "wrong-zone queued input never sends a POST")
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "a"})
    check(m.testX.postCount = 1 and m.state.pending, "allowed command sent once")
    check(ParseJson(m.testX.body).zone_id = "a", "wire command bound to explicit selection")
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "a"})
    check(m.testX.postCount = 1, "pending command rejects repeated input")
    handleResponse(fakeResponse("51", 200, "{}"))
    check(m.state.uncertain and not m.state.pending, "HTTP acceptance alone never reports success")
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "a"})
    check(m.testX.postCount = 1, "accepted but unreconciled command blocks a second POST")
    startTransfer("playing", "/now_playing", invalid)
    handleResponse(fakeResponse("51", 200, FormatJson(playing)))
    check(not m.state.uncertain and m.state.online, "post-command fresh GET unlocks input")
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "a"})
    expireRequests(10000)
    check(m.testX.cancelCount = 1 and m.state.uncertain, "POST timeout cancels without replay")
    check(m.testX.postCount = 2 and m.pending.Count() = 0, "POST timeout never retries the command")
    m.state.readonly = true
    m.state.uncertain = false
    handleRequest({kind: "command", action: "next", session: m.state.session, zone: "a"})
    check(m.testX.postCount = 2, "screensaver network dispatcher rejects POST request")
    m.state.readonly = false
    m.testX.started = false
    startTransfer("playing", "/now_playing", invalid)
    check(m.pending.Count() = 0 and not m.state.online, "failed request startup cannot leave an immortal pending transfer")
    m.sseEnabled = false
    m.sse = invalid
    startSSE()
    check(m.testX.sseCount = 0, "older OS never calls unavailable SSE method")
    check(SnapshotInterval(false) = 2000 and SnapshotInterval(true) = 30000, "polling fallback and SSE reconciliation are bounded")
    m.sseEnabled = true
    m.sseFailures = 0
    startSSE()
    check(m.sse = invalid and m.nextSse = 3000, "failed SSE startup schedules backoff")
    m.testX.started = true
    m.testX.retry = 20000
    startSSE()
    check(m.sse <> invalid and m.testX.sseCount = 2, "SSE uses its native streaming operation")
    m.sseReady = false
    handleSSE(fakeResponse("12", 200, ""))
    check(not m.sseReady, "late prior SSE stream event ignored")
    handleSSE(fakeResponse("51", 200, ""))
    check(m.sseReady and m.nextRead = 0, "current SSE event invalidates authoritative snapshot")
    handleResponse(fakeResponse("51", 200, ""))
    check(m.sse = invalid and not m.sseReady and m.nextSse = 21000, "SSE disconnect honors server retry and restores polling")
    old = m.state.session
    m.testX.started = true
    startTransfer("playing", "/now_playing", invalid)
    handleRequest({kind: "configure", bridge: "http://new:8088", zone: "b"})
    check(m.state.session = old + 1 and m.pending.Count() = 0, "bridge switch cancels previous transfers and advances session")
    check(m.state.zone = "b" and m.state.playing = invalid, "bridge switch clears old artwork/state")
    m.transportFactory = invalid
end sub

function fakeRegistry() as object
    return { values: {}, flushed: false,
        Read: function(key as string) as string
            if m.values.DoesExist(key) then return m.values[key]
            return ""
        end function,
        Write: sub(key as string, value as string)
            m.values[key] = value
        end sub,
        Flush: sub()
            m.flushed = true
        end sub }
end function

sub settingsTests()
    m.registries = { controller: fakeRegistry(), screensaver: fakeRegistry() }
    m.registryFactory = function(profile as string) as object
        return m.registries[profile]
    end function
    SaveSettings("controller", "http://bridge:8088", "a")
    SaveSettings("screensaver", "http://bridge:8088", "b")
    check(LoadSettings("controller").zone = "a", "controller zone pin persists")
    check(LoadSettings("screensaver").zone = "b", "screensaver pin stays independent")
    check(m.registries.controller.flushed and m.registries.screensaver.flushed, "both pins flushed to their registry")
    SaveSettings("controller", "http://new:8088/", "c")
    check(LoadSettings("controller").bridge = "http://new:8088", "loaded bridge root normalized")
    check(LoadSettings("screensaver").zone = "b", "controller settings cannot overwrite screensaver selection")
    status = {bridge: "http://bridge:8088", zone: "roon:a-long-internal-zone-id", notice: "", online: true, zones: [{zone_id: "roon:a-long-internal-zone-id", zone_name: "Front Family Room"}]}
    text = SettingsStatus(status)
    check(Instr(1, text, "Connected") > 0 and Instr(1, text, "Zone: Front Family Room") > 0, "successful pin shows connection and readable room name")
    check(Instr(1, text, "roon:a-long-internal-zone-id") = 0, "internal ID never crowds out pin confirmation")
    status.zones = []
    check(Instr(1, SettingsStatus(status), "Selected zone unavailable") > 0, "missing pin reports recovery without another-room fallback")
    status.zone = ""
    check(Instr(1, SettingsStatus(status), "Not selected") > 0, "unconfigured pin is explicit")
    m.registryFactory = invalid
end sub
