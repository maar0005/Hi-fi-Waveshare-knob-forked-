sub Main()
    m.failures = 0
    m.count = 0
    m.nodes = {heading: {text: ""}, status: {text: "", visible: true}}
    m.top = {FindNode: function(id as string) as object
        return m.nodes[id]
    end function}
    m.top.nodes = m.nodes
    m.choices = {visible: true, SetFocus: sub(value as boolean)
        m.focus = value
    end sub}
    m.zoneList = {visible: false, SetFocus: sub(value as boolean)
        m.focus = value
    end sub}
    m.discovery = {control: "STOP", result: invalid}
    m.discoveryGeneration = 0
    m.contentFactory = function() as object
        return {children: [], CreateChild: function(kind as string) as object
            item = {title: ""}
            m.children.Push(item)
            return item
        end function}
    end function
    findBridges()
    check(m.discovery.control = "RUN" and m.zoneList.visible and not m.choices.visible, "scan runs separately with focusable manual fallback")
    check(m.zoneList.content.children[0].title = "Enter an address", "manual entry available while scan pending")
    m.client = {snapshot: {notice: "Connecting"}}
    settingsSnapshot()
    check(m.nodes.status.text = "Looking for bridges on your network…", "playback connection status cannot overwrite active discovery")
    m.discovery.result = {generation: 0, bridges: [{bridge: "wrong"}], notice: "stale"}
    discoveryResult()
    check(m.bridgeOptions.Count() = 0, "stale scan cannot replace current choices")
    m.discovery.result = {generation: 1, bridges: [{bridge: "http://a:8088", name: "A"}, {bridge: "http://b:8088", name: "B"}], notice: "Pick a music bridge"}
    discoveryResult()
    check(m.bridgeOptions.Count() = 2 and m.zoneList.content.children.Count() = 3, "multiple verified bridges plus manual fallback")
    closeZones()
    check(m.discovery.control = "STOP" and not m.zoneList.visible and m.choices.visible, "Back cancels scan and restores Settings focus")
    discoveryResult()
    check(not m.zoneList.visible, "late result cannot reopen canceled scan")
    if m.failures > 0 then stop
    print "PASS all discovery UI tests: "; m.count
end sub

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub
