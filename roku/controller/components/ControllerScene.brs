sub init()
    artInit(false)
    m.controls = false
    m.index = 1
    m.labels = ["Previous", "Play / Pause", "Next", "Volume −", "Volume +", "Zones / Settings"]
    m.actions = ["previous", "play_pause", "next", "vol_down", "vol_up", "settings"]
    m.timer = m.top.FindNode("hideTimer")
    m.timer.ObserveField("fire", "hideControls")
    m.top.SetFocus(true)
end sub

sub hideControls()
    m.controls = false
    updateController()
end sub

sub revealControls()
    m.controls = true
    m.timer.control = "stop"
    m.timer.control = "start"
    updateController()
end sub

sub updateController()
    m.top.FindNode("controlsMat").visible = m.controls
    label = m.top.FindNode("controlLabel")
    label.visible = m.controls
    m.top.FindNode("controlHint").visible = m.controls
    item = m.labels[m.index]
    available = true
    if m.snapshot <> invalid and m.index < 5
        available = m.snapshot.allowed[m.actions[m.index]] = true
        if m.index = 1 and m.snapshot.playing <> invalid
            if m.snapshot.playing.is_playing then item = "Pause" else item = "Play"
        end if
    else if m.index < 5
        available = false
    end if
    label.color = "0xEEE8DAFF"
    if not available
        item += " — unavailable"
        label.color = "0xBBB5A7FF"
    end if
    label.text = "[ " + item + " ]"
end sub

sub sendCommand(action as string)
    if m.snapshot = invalid then return
    ' Task independently validates capability, freshness and selected-session identity.
    m.client.request = { kind: "command", action: action, zone: m.snapshot.zone, session: m.snapshot.session }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press
        m.heldKey = ""
        return false
    end if
    ' Ignore repeated held transport/OK inputs. Volume remains deliberate single presses.
    if m.heldKey = key then return true
    m.heldKey = key
    if key = "options"
        m.top.openSettings = true
        return true
    end if
    if key = "back"
        if m.controls
            hideControls()
            return true
        end if
        return false
    end if
    if key = "play" or key = "playonly" or key = "pause" or key = "rewind" or key = "fastforward"
        action = "play_pause"
        if key = "playonly" then action = "play"
        if key = "pause" then action = "pause"
        if key = "rewind" then action = "previous"
        if key = "fastforward" then action = "next"
        sendCommand(action)
        return true
    end if
    if key = "OK" or key = "up" or key = "down" or key = "left" or key = "right"
        if not m.controls
            revealControls()
            return true
        end if
        if key = "left" or key = "up" then m.index = (m.index + 5) mod 6
        if key = "right" or key = "down" then m.index = (m.index + 1) mod 6
        if key = "OK"
            if m.actions[m.index] = "settings"
                m.top.openSettings = true
            else
                sendCommand(m.actions[m.index])
            end if
        end if
        revealControls()
        return true
    end if
    return false
end function
