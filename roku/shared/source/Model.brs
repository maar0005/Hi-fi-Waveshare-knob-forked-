function NormalizeBridge(value as dynamic) as string
    if type(value) <> "String" and type(value) <> "roString" then return ""
    value = value.Trim()
    if Len(value) > 256 then return ""
    re = CreateObject("roRegex", "^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?/?$", "i")
    if not re.IsMatch(value) then return ""
    if Right(value, 1) = "/" then value = Left(value, Len(value) - 1)
    return value
end function

function TextField(value as dynamic, key as string) as string
    if type(value) <> "roAssociativeArray" then return ""
    text = value[key]
    if type(text) = "String" or type(text) = "roString" then return text
    return ""
end function

function HasZone(zones as dynamic, zone as string) as boolean
    if type(zones) <> "roArray" or zone = "" then return false
    for each item in zones
        if TextField(item, "zone_id") = zone then return true
    end for
    return false
end function

function NewClientState(readonly as boolean) as object
    return { readonly: readonly, session: 0, bridge: "", zone: "", zones: [], playing: invalid, online: false, pending: false, uncertain: false, freshAt: -100000, notice: "Choose bridge and zone" }
end function

sub ResetClient(state as object, bridge as string, zone as string)
    state.session++
    state.bridge = bridge
    state.zone = zone
    state.zones = []
    state.playing = invalid
    state.online = false
    state.pending = false
    state.uncertain = false
    state.freshAt = -100000
    state.notice = "Connecting"
    if zone = "" then state.notice = "Pin a listening zone in settings"
    if bridge = "" then state.notice = "Configure bridge and pinned zone in settings"
end sub

function AcceptPlaying(state as object, session as integer, zone as string, body as dynamic, now as integer) as boolean
    if session <> state.session or zone <> state.zone then return false
    if not HasZone(state.zones, zone) then return false
    if TextField(body, "zone_id") <> zone then return false
    if type(body.is_playing) <> "Boolean" and type(body.is_playing) <> "roBoolean" then return false
    state.playing = body
    state.online = true
    state.freshAt = now
    ' Never release a command still on the wire because an earlier GET completed.
    if not state.pending then state.uncertain = false
    state.notice = ""
    return true
end function

function AllowsCommand(state as object, action as string, now as integer) as boolean
    if state.readonly or not state.online or state.pending or state.uncertain then return false
    if now - state.freshAt > 10000 then return false
    if not HasZone(state.zones, state.zone) then return false
    p = state.playing
    if type(p) <> "roAssociativeArray" then return false
    if action = "play_pause"
        if p.is_playing = true then return TrueField(p, "is_pause_allowed")
        return TrueField(p, "is_play_allowed")
    end if
    if action = "play" then return TrueField(p, "is_play_allowed")
    if action = "pause" then return TrueField(p, "is_pause_allowed")
    if action = "next" then return TrueField(p, "is_next_allowed")
    if action = "previous" then return TrueField(p, "is_previous_allowed")
    if action = "vol_up" or action = "vol_down"
        kind = TextField(p, "volume_type")
        if kind <> "db" and kind <> "number" then return false
        return IsNumericValue(p.volume)
    end if
    return false
end function

function IsNumericValue(value as dynamic) as boolean
    t = type(value)
    return t = "Integer" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble"
end function

function SupportsSSE(major as dynamic) as boolean
    if major = invalid then return false
    return Val(major.ToStr()) >= 16
end function

function ArtViewport(width as integer, height as integer, readonly as boolean) as object
    strip = 36
    if readonly then strip = 0
    return { width: width, height: height - strip, strip: strip }
end function

function RetryDelay(failures as integer) as integer
    delay = 1000
    for n = 1 to failures
        delay *= 2
        if delay >= 60000 then return 60000
    end for
    return delay
end function

function ArtIdentity(state as object) as string
    if state.playing = invalid then return ""
    return state.session.ToStr() + ":" + state.zone + ":" + TextField(state.playing, "image_key")
end function

function SnapshotInterval(sseReady as boolean) as integer
    if sseReady then return 30000
    return 2000
end function

function TrueField(value as object, key as string) as boolean
    field = value[key]
    if type(field) <> "Boolean" and type(field) <> "roBoolean" then return false
    return field
end function
