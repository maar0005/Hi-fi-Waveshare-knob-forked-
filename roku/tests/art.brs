sub Main()
    m.failures = 0
    m.count = 0
    m.artKey = "session:room:cover-b"
    m.loading = { artGeneration: 2, artIdentity: m.artKey, visible: false, loadStatus: "ready" }
    m.shown = { artGeneration: 0, artIdentity: "cover-old" }
    m.metadata = { text: "", visible: false }
    m.layer = { removed: 0, RemoveChild: sub(node as object)
        m.removed++
    end sub }
    stale = { artGeneration: 1, artIdentity: "session:room:cover-a", visible: false, loadStatus: "ready" }
    artLoaded(artEvent(stale))
    check(not stale.visible and m.layer.removed = 0, "late image generation cannot replace current artwork")
    wrongSession = { artGeneration: 2, artIdentity: "old-session:room:cover-b", visible: false, loadStatus: "ready" }
    artLoaded(artEvent(wrongSession))
    check(not wrongSession.visible, "wrong session cannot display even with current generation")
    current = m.loading
    artLoaded(artEvent(current))
    check(current.visible and m.loading = invalid and m.layer.removed = 1, "ready current image swaps and releases old poster")
    artLoaded(artEvent(stale))
    check(m.layer.removed = 1, "duplicate late callback after swap ignored")
    m.loading = { artGeneration: 3, artIdentity: m.artKey, visible: false, loadStatus: "failed" }
    artLoaded(artEvent(m.loading))
    check(m.loading = invalid and m.artKey = "", "failed image releases pending texture and permits retry")
    check(m.metadata.visible and m.metadata.text <> "", "failed artwork has a truthful error notice")
    clearArt()
    check(m.shown = invalid and m.layer.removed = 3, "clear on missing or changed zone releases displayed image")
    if m.failures = 0 then print "PASS all artwork tests: "; m.count
end sub

function artEvent(node as object) as object
    return { node: node, GetRoSGNode: function() as object
        return m.node
    end function }
end function

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub
