sub Main()
    m.failures = 0
    m.count = 0
    m.top = { node: { visible: false, text: "" }, FindNode: function(id as string) as object
        return m.node
    end function }
    m.controls = false
    m.heldKey = ""
    m.index = 1
    m.labels = ["Previous", "Play / Pause", "Next", "Volume -", "Volume +", "Settings"]
    m.actions = ["previous", "play_pause", "next", "vol_down", "vol_up", "settings"]
    m.timer = {control: "stop"}
    m.client = {}
    m.snapshot = {zone: "pinned-room", session: 3, allowed: {previous: true, play_pause: true, next: true, vol_down: false, vol_up: false}}
    check(onKeyEvent("OK", true) and m.controls, "first OK reveals controls")
    check(m.client.request = invalid, "revealing art controls never sends a command")
    onKeyEvent("OK", true)
    check(m.client.request = invalid, "held OK cannot activate newly revealed control")
    onKeyEvent("OK", false)
    onKeyEvent("OK", true)
    check(m.client.request.action = "play_pause" and m.client.request.zone = "pinned-room", "released then pressed OK sends explicit pinned-zone command")
    m.client.request = invalid
    onKeyEvent("OK", true)
    check(m.client.request = invalid, "held transport activation not repeated")
    onKeyEvent("OK", false)
    onKeyEvent("right", true)
    check(m.index = 2, "arrows navigate overlay")
    onKeyEvent("right", false)
    onKeyEvent("options", true)
    check(m.top.openSettings = true, "Options opens pin/settings entry point")
    onKeyEvent("options", false)
    check(onKeyEvent("back", true) and not m.controls, "Back dismisses overlay first")
    onKeyEvent("back", false)
    check(not onKeyEvent("back", true), "second Back permits leaving app")
    onKeyEvent("back", false)
    check(not onKeyEvent("Home", true), "Home not intercepted")
    onKeyEvent("Home", false)
    check(not onKeyEvent("volumeup", true), "TV volume not falsely mapped to room volume")
    onKeyEvent("volumeup", false)
    onKeyEvent("fastforward", true)
    check(m.client.request.action = "next" and m.client.request.session = 3, "transport request retains current selection token")
    revealControls()
    hideControls()
    check(not m.controls, "idle timer returns to art")
    if m.failures = 0 then print "PASS all remote tests: "; m.count
end sub

sub artInit(readonly as boolean)
end sub

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub
