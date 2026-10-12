sub init()
    artInit(false)
    m.controls = false
    m.heldKey = ""
    m.index = 1
    m.labels = ["Previous", "Play / Pause", "Next", "Volume −", "Volume +", "Library", "Settings"]
    m.actions = ["previous", "play_pause", "next", "vol_down", "vol_up", "library", "settings"]
    m.library = m.top.FindNode("libraryPanel")
    m.library.client = m.client
    m.library.ObserveField("done", "closeLibrary")
    m.timer = m.top.FindNode("hideTimer")
    m.timer.ObserveField("fire", "hideControls")
    m.fade = m.top.FindNode("controlsFade")
    m.top.SetFocus(true)
end sub

sub hideControls()
    if m.fade <> invalid then m.fade.control = "stop"
    m.controls = false
    updateController()
end sub

sub revealControls()
    fresh = not m.controls
    m.controls = true
    if fresh and m.fade <> invalid
        m.fade.control = "stop"
        m.fade.control = "start"
    end if
    m.timer.control = "stop"
    m.timer.control = "start"
    updateController()
end sub

sub updateController()
    if m.library <> invalid then m.library.snapshot = m.snapshot
    m.top.FindNode("controlsGroup").visible = m.controls
    positions = [[16,12], [304,12], [592,12], [16,68], [304,68], [880,12], [592,68]]
    for i = 0 to m.labels.Count() - 1
        label = m.top.FindNode("control" + i.ToStr())
        item = m.labels[i]
        available = true
        if i < 5
            available = false
            if m.snapshot <> invalid then available = m.snapshot.allowed[m.actions[i]] = true
            if i = 1 and m.snapshot <> invalid
                if m.snapshot.playing <> invalid
                    if m.snapshot.playing.is_playing then item = "Pause" else item = "Play"
                end if
            end if
        end if
        label.text = item
        label.color = "0xEEE8DAFF"
        if not available then label.color = "0xA39D91FF"
        if i = m.index then label.color = "0x101012FF"
    end for
    m.top.FindNode("focusPlate").translation = positions[m.index]
    m.top.FindNode("controlHint").text = "Arrows choose · OK select · Back artwork · Options settings"
    if m.index < 5 and m.snapshot <> invalid
        if not m.snapshot.allowed[m.actions[m.index]] then m.top.FindNode("controlHint").text = "Unavailable for this room right now · Back artwork · Options settings"
    end if

end sub

sub sendCommand(action as string)
    if m.snapshot = invalid then return
    capability = action
    if action = "play" or action = "pause" then capability = "play_pause"
    if not m.snapshot.allowed[capability] then return
    ' Task independently validates capability, freshness and selected-session identity.
    m.client.request = { kind: "command", action: action, zone: m.snapshot.zone, session: m.snapshot.session }
end sub

sub closeLibrary()
    if not m.library.done then return
    hideControls()
    m.heldKey = ""
    m.top.SetFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.library <> invalid
        if m.library.visible then return false
    end if
    if not press
        m.heldKey = ""
        return false
    end if
    ' Navigation repeats; transport and OK require a new press.
    if key = "OK" or key = "play" or key = "rewind" or key = "fastforward"
        if m.heldKey = key then return true
    end if
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
    if key = "up" and not m.controls
        openMusic()
        return true
    end if
    if key = "OK" or key = "up" or key = "down" or key = "left" or key = "right"
        if not m.controls
            revealControls()
            return true
        end if
        primary = [0, 1, 2, 5]
        secondary = [3, 4, 6]
        row = primary
        if m.index = 3 or m.index = 4 or m.index = 6 then row = secondary
        col = 0
        for i = 0 to row.Count() - 1
            if row[i] = m.index then col = i
        end for
        if key = "left" then m.index = row[(col + row.Count() - 1) mod row.Count()]
        if key = "right" then m.index = row[(col + 1) mod row.Count()]
        if key = "down"
            if col > 2 then col = 2
            m.index = secondary[col]
        end if
        if key = "up" then m.index = primary[col]
        if key = "OK"
            if m.actions[m.index] = "settings"
                m.top.openSettings = true
            else if m.actions[m.index] = "library"
                openMusic()
                return true
            else
                sendCommand(m.actions[m.index])
            end if
        end if
        revealControls()
        return true
    end if
    return false
end function

sub openMusic()
    if m.snapshot = invalid then return
    hideControls()
    m.timer.control = "stop"
    m.heldKey = ""
    m.library.open = true
end sub
