sub Main()
    m.count = 0
    m.failures = 0
    m.top = fakeTop()
    init()
    m.contentFactory = function() as object
        return {children: [], CreateChild: function(kind as string) as object
            item = {title: ""}
            m.children.Push(item)
            return item
        end function}
    end function
    m.top.client = {request: invalid, ObserveField: sub(field as string, callback as string)
        end sub, UnobserveField: sub(field as string)
        end sub}
    m.top.snapshot = {session: 1, zone: "roon:room", zones: [{zone_id: "roon:room", zone_name: "Listening room", browse_supported: true, library_tabs: ["browse", "playlists", "radio"]}]}
    libraryContext()
    m.top.open = true
    openLibrary()
    check(m.top.visible and m.rows.Count() = 5, "menu shows only published tabs, search and return")
    check(m.rows[2].tab = "radio" and m.rows[3].kind = "search", "Roon menu excludes fake Favorites/current queue")
    check(m.list.focused, "native list gets remote focus")
    m.list.itemSelected = 0
    librarySelected()
    check(m.busy and m.mode = "loading" and m.rows.Count() = 1 and m.rows[0].kind = "return", "browse loading cannot activate previous rows")
    check(m.top.client.request.operation = "browse" and m.top.client.request.zone = "roon:room", "UI request bound to pinned room")
    firstId = m.requestId
    deliver(firstId, "ok", [{title: "Album", subtitle: "Artist", location: "loc-album", ref: "ref-album"}, {title: "Folder", subtitle: "", location: "loc-folder", ref: ""}], 20)
    check(m.mode = "results" and m.rows.Count() = 3 and m.rows[2].kind = "more", "rows plus explicit forward page")
    check(m.crumbs.text = "Library / Albums", "server breadcrumbs shown")
    m.list.itemSelected = 0
    m.list.itemFocused = 0
    librarySelected()
    check(m.mode = "actions" and m.rows[0].kind = "restore", "held OK lands on Back rather than auto-playing")
    check(m.rows[1].kind = "folder" and m.rows[2].action = "play" and m.rows[3].action = "queue", "folder+ref offers Open and deliberate playback choices")
    m.list.itemSelected = 0
    librarySelected()
    check(m.mode = "results" and m.list.jumpToItem = 0, "Back to list restores focused item")
    m.list.itemSelected = 1
    m.list.itemFocused = 1
    librarySelected()
    check(m.top.client.request.location = "loc-folder" and m.history.Count() = 1, "folder navigation uses opaque location")
    check(m.history[0].focus = 1, "remember parent selection before navigation")
    stale = firstId
    active = m.requestId
    deliver(stale, "ok", [{title: "Old", ref: "old", location: "", subtitle: ""}], invalid)
    check(m.busy and m.rows.Count() = 1, "same-zone late UI callback cannot replace newer page")
    deliver(active, "ok", [], invalid)
    check(m.notice.text <> "" and m.rows[0].kind = "return", "empty page has recovery copy")
    onKeyEvent("back", true)
    check(m.current.focus = 1 and m.current.location = "" and m.top.client.request.location = "", "Back re-reads parent descriptor, not expired cached refs")
    deliver(m.requestId, "ok", [{title: "Album", subtitle: "Artist", location: "loc-album", ref: "fresh"}, {title: "Folder", subtitle: "", location: "loc-folder", ref: ""}], 20)
    check(m.list.jumpToItem = 1, "Back restores parent focus after refreshed results")
    m.list.itemSelected = 2
    m.list.itemFocused = 2
    librarySelected()
    check(m.top.client.request.offset = 20 and m.history[0].focus = 2, "More results retains paging return location and focus")
    deliver(m.requestId, "error", [], invalid)
    check(m.mode = "error" and m.rows[0].kind = "retry", "error view requires deliberate Refresh")
    m.list.itemSelected = 0
    librarySelected()
    check(m.busy and m.top.client.request.offset = 20, "Refresh retries read only on the same page")
    deliver(m.requestId, "ok", [{title: "Track", subtitle: "Artist", location: "", ref: "fresh-track"}], invalid)
    m.list.itemSelected = 0
    m.list.itemFocused = 0
    librarySelected()
    check(m.rows.Count() = 3 and m.rows[1].action = "play", "track chooser has deliberate Play/Add actions")
    check(m.rows[1].title = "Play" and m.crumbs.text = "Listening room", "plain Play action retains human room destination")
    m.list.itemSelected = 1
    librarySelected()
    check(m.busy and m.top.client.request.kind = "library_play" and m.top.client.request.ref = "fresh-track", "Play dispatches opaque item ref")
    m.top.client.request.testNonce = true
    librarySelected()
    check(m.top.client.request.testNonce = true, "busy UI rejects repeated mutation selection")
    deliver(m.requestId, "accepted", [], invalid)
    check(not m.top.visible and m.top.done and m.top.client.request.kind = "library_close", "accepted Play returns to full artwork and cancels stale reads")
    m.top.open = true
    openLibrary()
    check(m.top.client.request.offset = 20, "reopening Library resumes previous page via fresh read")
    deliver(m.requestId, "ok", [{title: "Track", subtitle: "", location: "", ref: "next-track"}], invalid)
    m.top.client.libraryResult = {requestId: m.requestId, session: 9, zone: "roon:other", status: "ok", data: {rows: []}}
    onLibraryResult()
    check(m.rows[0].ref = "next-track", "old-room result is rejected at render boundary too")
    m.top.snapshot = {session: 2, zone: "roon:other", zones: [{zone_id: "roon:other", zone_name: "Other room", browse_supported: true, library_tabs: ["browse"]}]}
    libraryContext()
    check(not m.top.visible and m.current = invalid and m.history.Count() = 0 and m.rows.Count() = 0, "room change clears visible library and resume history")
    m.top.open = true
    openLibrary()
    check(m.rows.Count() = 3, "new room starts at its own menu")
    m.top.snapshot = {session: 2, zone: "roon:other", zones: []}
    libraryContext()
    check(not m.top.visible and m.current = invalid, "removed pinned room closes library without redirect")
    m.top.snapshot = {session: 3, zone: "musicassistant:room", zones: [{zone_id: "musicassistant:room", zone_name: "MA", browse_supported: true, library_tabs: ["browse"]}]}
    libraryContext()
    m.top.open = true
    openLibrary()
    check(m.rows[2].kind = "queue", "MA menu exposes supported current queue")
    m.dialogFactory = function() as object
        return {text: "", buttonSelected: 1, ObserveField: sub(field as string, callback as string)
        end sub}
    end function
    searchLibrary()
    m.dialog.text = " Adele "
    m.dialog.buttonSelected = 0
    searchChosen()
    check(m.top.client.request.operation = "search" and m.top.client.request.query = "Adele", "native keyboard submits trimmed search to pinned provider")
    check(m.top.scene.dialog.close and m.dialog = invalid, "search keyboard closes and releases focus")
    deliver(m.requestId, "ok", [{title: "Search hit", subtitle: "", ref: "search-ref", location: ""}], invalid)
    onKeyEvent("options", true)
    check(m.mode = "menu" and m.top.client.request.kind = "library_close", "Options menu cancels in-flight/resumable refs")
    check(not onKeyEvent("Home", true), "Library never intercepts Roku Home")
    searchLibrary()
    abandoned = m.dialog
    m.top.snapshot = {session: 4, zone: "roon:new", zones: [{zone_id: "roon:new"}]}
    libraryContext()
    check(abandoned.close and m.dialog = invalid and not m.top.visible, "room change dismisses search keyboard and stale submission")
    priorId = m.requestId
    searchChosen()
    check(m.requestId = priorId, "closed old-room keyboard cannot trigger new-room search")
    m.top.snapshot = {session: 5, zone: "roon:room", zones: [{zone_id: "roon:room", zone_name: "Listening room", browse_supported: true, library_tabs: ["browse"]}]}
    libraryContext()
    m.top.open = true
    openLibrary()
    searchLibrary()
    m.list.focused = false
    searchDismissed({node: m.dialog, GetRoSGNode: function() as object
        return m.node
    end function})
    check(m.dialog = invalid and m.list.focused, "keyboard Back dismissal restores list focus without submitting")
    requestPage(libraryPage("search", "Search: missing", "browse", "", 0, "missing"))
    deliver(m.requestId, "ok", [], invalid)
    check(m.rows[0].kind = "search" and m.rows[1].kind = "return", "empty search offers another search and return")
    requestPage(libraryPage("browse", "Albums"))
    deliver(m.requestId, "ok", [{title: "Track", subtitle: "Artist", ref: "queue-ref", location: ""}], invalid)
    m.list.itemSelected = 0
    librarySelected()
    m.list.itemSelected = 2
    librarySelected()
    m.top.client.libraryResult = {requestId: m.requestId, session: m.context.session, zone: m.context.zone, status: "accepted", notice: "Checking your queue…", data: {action: "queue"}}
    onLibraryResult()
    check(m.title.text = "Albums · Listening room" and m.notice.text = "Checking your queue…", "accepted queue restores list heading and keeps acknowledgement")
    m.list.itemSelected = 0
    librarySelected()
    m.list.itemSelected = 1
    librarySelected()
    request = m.top.client.request
    onKeyEvent("back", true)
    check(not m.top.visible and m.top.client.request.kind = "library_close", "Back during pending Play returns to artwork without sending another mutation")
    if m.failures = 0 then print "PASS all library UI tests: "; m.count
end sub

sub deliver(id as integer, status as string, rows as object, nextOffset as dynamic)
    data = {rows: rows, nextOffset: nextOffset, breadcrumbs: [{title: "Library"}, {title: "Albums"}]}
    if status = "accepted" then data = {action: "play"}
    m.top.client.libraryResult = {requestId: id, session: m.context.session, zone: m.context.zone, status: status, notice: "Request status", data: data}
    onLibraryResult()
end sub

function fakeTop() as object
    nodes = {}
    for each id in ["libraryList", "libraryTitle", "libraryCrumbs", "libraryNotice"]
        nodes[id] = {visible: false, text: "", itemFocused: 0, itemSelected: 0, ObserveField: sub(field as string, callback as string)
            end sub, SetFocus: sub(focused as boolean)
                m.focused = focused
            end sub}
    end for
    return {nodes: nodes, scene: {}, FindNode: function(id as string) as object
        return m.nodes[id]
    end function, GetScene: function() as object
        return m.scene
    end function}
end function

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub
