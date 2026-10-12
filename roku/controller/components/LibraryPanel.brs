sub init()
    m.list = m.top.FindNode("libraryList")
    m.title = m.top.FindNode("libraryTitle")
    m.crumbs = m.top.FindNode("libraryCrumbs")
    m.notice = m.top.FindNode("libraryNotice")
    m.list.ObserveField("itemSelected", "librarySelected")
    m.history = []
    m.rows = []
    m.current = invalid
    m.context = invalid
    m.requestId = 0
    m.dialogSequence = 0
    m.mode = "menu"
    m.busy = false
    m.selected = invalid
    m.top.visible = false
end sub

sub libraryContext()
    state = m.top.snapshot
    if state = invalid then return
    if m.context <> invalid
        if state.session <> m.context.session or state.zone <> m.context.zone
            m.history = []
            m.current = invalid
            m.rows = []
            if m.top.visible then leaveLibrary()
        else if not HasZone(state.zones, state.zone)
            m.history = []
            m.current = invalid
            m.rows = []
            if m.top.visible then leaveLibrary()
        end if
    end if
    m.context = state
end sub

sub openLibrary()
    if not m.top.open or m.context = invalid then return
    m.top.client.UnobserveField("libraryResult")
    m.top.client.ObserveField("libraryResult", "onLibraryResult")
    m.top.visible = true
    m.top.done = false
    m.notice.text = ""
    if m.current <> invalid
        requestPage(m.current)
    else
        libraryMenu()
    end if
end sub

sub libraryMenu()
    cancelLibrary()
    m.mode = "menu"
    m.busy = false
    zone = LibraryZone(m.context.zones, m.context.zone)
    m.title.text = "Library · " + TextField(zone, "zone_name")
    m.crumbs.text = "Choose something to listen to"
    rows = []
    for each tabName in LibraryTabs(zone)
        labels = { browse: "Browse library", playlists: "Playlists", favorites: "Favorites", radio: "Radio" }
        rows.Push({ title: labels[tabName], kind: "tab", tab: tabName })
    end for
    if LibrarySource(m.context.zone) <> ""
        if rows.Count() > 0 then rows.Push({ title: "Search", kind: "search" })
        if LibrarySource(m.context.zone) = "musicassistant" then rows.Push({ title: "Current queue", kind: "queue" })
    end if
    rows.Push({ title: "Back to artwork", kind: "close" })
    if rows.Count() = 1 then m.notice.text = "This room has no music library. Choose another room in Settings."
    showRows(rows, 0)
end sub

sub cancelLibrary()
    if m.context = invalid then return
    m.requestId++
    m.top.client.request = { kind: "library_close", session: m.context.session, zone: m.context.zone, requestId: m.requestId }
end sub

sub leaveLibrary()
    if m.dialog <> invalid
        m.dialog.close = true
        m.dialog = invalid
    end if
    if m.current <> invalid and m.mode = "results" then m.current.focus = m.list.itemFocused
    cancelLibrary()
    m.top.visible = false
    m.busy = false
    m.top.done = true
end sub

sub showRows(rows as object, focus as integer)
    m.rows = rows
    if m.contentFactory <> invalid
        content = m.contentFactory()
    else
        content = CreateObject("roSGNode", "ContentNode")
    end if
    for each row in rows
        item = content.CreateChild("ContentNode")
        text = TextField(row, "title")
        subtitle = TextField(row, "subtitle")
        if subtitle <> "" then text += " · " + subtitle
        item.title = text
    end for
    m.list.content = content
    if focus < 0 then focus = 0
    if focus >= rows.Count() then focus = rows.Count() - 1
    if focus >= 0 then m.list.jumpToItem = focus
    m.list.SetFocus(true)
end sub

sub requestPage(page as object)
    m.current = page
    m.mode = "loading"
    m.busy = true
    m.selected = invalid
    m.requestId++
    zone = LibraryZone(m.context.zones, m.context.zone)
    m.title.text = page.title + " · " + TextField(zone, "zone_name")
    m.crumbs.text = ""
    m.notice.text = "Finding your music…"
    showRows([{title: "Back to music", kind: "return"}], 0)
    req = { kind: "library", operation: page.operation, tab: page.tab, location: page.location, offset: page.offset, query: page.query, session: m.context.session, zone: m.context.zone, requestId: m.requestId }
    m.top.client.request = req
end sub

function libraryPage(operation as string, title as string, tabName = "browse" as string, location = "" as string, offset = 0 as integer, query = "" as string) as object
    return { operation: operation, title: title, tab: tabName, location: location, offset: offset, query: query, focus: 0 }
end function

sub rememberPage()
    if m.current = invalid then return
    if m.mode = "results" then m.current.focus = m.list.itemFocused
    ' Bound navigation history; page descriptors only, never persisted playable refs.
    if m.history.Count() >= 40 then m.history.Shift()
    m.history.Push(m.current)
end sub

sub onLibraryResult()
    result = m.top.client.libraryResult
    if not m.top.visible or result = invalid then return
    if m.context = invalid then return
    if result.session <> m.context.session or result.zone <> m.context.zone or result.requestId <> m.requestId then return
    m.busy = false
    if result.status = "accepted"
        m.notice.text = result.notice
        if TextField(result.data, "action") = "play"
            leaveLibrary()
        else
            restoreResults()
            m.notice.text = result.notice
        end if
        return
    end if
    if result.status <> "ok"
        m.mode = "error"
        m.selected = invalid
        m.notice.text = result.notice
        showRows([{title: "Refresh", kind: "retry"}, {title: "Library menu", kind: "menu"}], 0)
        return
    end if
    m.mode = "results"
    m.resultRows = result.data.rows
    m.nextOffset = result.data.nextOffset
    crumbs = ""
    if type(result.data.breadcrumbs) = "roArray"
        for each crumb in result.data.breadcrumbs
            if crumbs <> "" then crumbs += " / "
            crumbs += TextField(crumb, "title")
        end for
    end if
    m.crumbs.text = crumbs
    restoreResults()
end sub

sub restoreResults()
    m.title.text = m.current.title + " · " + roomName()
    m.mode = "results"
    rows = []
    for each row in m.resultRows
        rows.Push({ title: row.title, subtitle: row.subtitle, location: row.location, ref: row.ref, kind: "item" })
    end for
    if m.nextOffset <> invalid then rows.Push({ title: "More results", kind: "more" })
    m.notice.text = ""
    if rows.Count() = 0
        m.notice.text = "Nothing here yet. Back returns to your music."
        if m.current.operation = "search"
            m.notice.text = "No matches. Try another artist, album, or song."
            rows.Push({ title: "Search again", kind: "search" })
        end if
        rows.Push({ title: "Back to music", kind: "return" })
    end if
    showRows(rows, m.current.focus)
end sub

sub librarySelected()
    index = m.list.itemSelected
    if index < 0 or index >= m.rows.Count() then return
    row = m.rows[index]
    if row.kind = "return"
        libraryBack()
        return
    end if
    if m.busy then return
    if row.kind = "close"
        leaveLibrary()
    else if row.kind = "menu"
        libraryMenu()
    else if row.kind = "retry"
        if m.current <> invalid then requestPage(m.current)
    else if row.kind = "tab"
        m.history = []
        requestPage(libraryPage("browse", row.title, row.tab))
    else if row.kind = "search"
        searchLibrary()
    else if row.kind = "queue"
        m.history = []
        requestPage(libraryPage("queue", "Current queue"))
    else if row.kind = "more"
        rememberPage()
        page = libraryPage(m.current.operation, m.current.title, m.current.tab, m.current.location, m.nextOffset, m.current.query)
        requestPage(page)
    else if row.kind = "item"
        m.current.focus = index
        m.selected = row
        if row.location <> "" and row.ref = ""
            openFolder()
        else if row.ref <> ""
            itemActions()
        else
            m.notice.text = "This item cannot be played. Choose another."
        end if
    else if row.kind = "restore"
        m.title.text = m.current.title + " · " + TextField(LibraryZone(m.context.zones, m.context.zone), "zone_name")
        restoreResults()
    else if row.kind = "folder"
        openFolder()
    else if row.kind = "action"
        m.busy = true
        m.notice.text = "Asking " + roomName() + " to play…"
        if row.action = "queue" then m.notice.text = "Adding to " + roomName() + "’s queue…"
        m.top.client.request = { kind: "library_play", action: row.action, ref: m.selected.ref, zone: m.context.zone, session: m.context.session, requestId: m.requestId }
    end if
end sub

sub itemActions()
    m.mode = "actions"
    m.title.text = m.selected.title
    rows = [{ title: "Back to list", kind: "restore" }]
    if m.selected.location <> "" then rows.Push({ title: "Open", kind: "folder" })
    rows.Push({ title: "Play", kind: "action", action: "play" })
    rows.Push({ title: "Add to queue", kind: "action", action: "queue" })
    m.crumbs.text = roomName()
    m.notice.text = ""
    showRows(rows, 0)
end sub

sub openFolder()
    rememberPage()
    requestPage(libraryPage("browse", m.selected.title, m.current.tab, m.selected.location))
end sub

sub searchLibrary()
    m.dialogSession = m.context.session
    m.dialogZone = m.context.zone
    if m.dialogFactory <> invalid
        m.dialog = m.dialogFactory()
    else
        m.dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    end if
    m.dialogSequence++
    m.dialog.id = "search-" + m.dialogSequence.ToStr()
    m.dialog.title = "Search music"
    m.dialog.buttons = ["Search", "Cancel"]
    m.dialog.ObserveField("buttonSelected", "searchChosen")
    m.dialog.ObserveField("wasClosed", "searchDismissed")
    m.top.GetScene().dialog = m.dialog
end sub

sub searchChosen()
    if m.dialog = invalid then return
    if m.context.session <> m.dialogSession or m.context.zone <> m.dialogZone
        m.dialog.close = true
        m.dialog = invalid
        return
    end if
    accepted = m.dialog.buttonSelected = 0
    query = m.dialog.text.Trim()
    if accepted and (query = "" or Len(query) > 256)
        m.dialog.title = "Type an artist, album, or song"
        return
    end if
    dialog = m.dialog
    m.dialog = invalid
    dialog.close = true
    m.list.SetFocus(true)
    if accepted
        m.history = []
        requestPage(libraryPage("search", "Search: " + query, "browse", "", 0, query))
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "options"
        libraryMenu()
        return true
    end if
    if key <> "back" then return false
    libraryBack()
    return true
end function

sub libraryBack()
    if m.busy and m.mode = "actions"
        leaveLibrary()
        return
    end if
    if m.mode = "actions"
        m.title.text = m.current.title + " · " + TextField(LibraryZone(m.context.zones, m.context.zone), "zone_name")
        restoreResults()
    else if m.mode = "menu"
        leaveLibrary()
    else if m.history.Count() > 0
        requestPage(m.history.Pop())
    else
        libraryMenu()
    end if
end sub

function roomName() as string
    return TextField(LibraryZone(m.context.zones, m.context.zone), "zone_name")
end function

sub searchDismissed(event as object)
    if m.dialog = invalid then return
    if event.GetRoSGNode().id <> m.dialog.id then return
    m.dialog = invalid
    if m.top.visible then m.list.SetFocus(true)
end sub
