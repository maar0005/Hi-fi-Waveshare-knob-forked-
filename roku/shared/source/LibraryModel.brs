function LibraryZone(zones as dynamic, zoneId as string) as object
    if type(zones) = "roArray"
        for each zone in zones
            if TextField(zone, "zone_id") = zoneId then return zone
        end for
    end if
    return {}
end function

function LibraryTabs(zone as object) as object
    tabs = []
    if not TrueField(zone, "browse_supported") then return tabs
    if type(zone.library_tabs) <> "roArray" then return tabs
    for each tabName in zone.library_tabs
        if type(tabName) = "String" or type(tabName) = "roString"
            if tabName = "browse" or tabName = "playlists" or tabName = "favorites" or tabName = "radio"
                if not LibraryContains(tabs, tabName) then tabs.Push(tabName)
            end if
        end if
    end for
    return tabs
end function

function LibraryContains(values as object, value as dynamic) as boolean
    for each item in values
        if item = value then return true
    end for
    return false
end function

function LibrarySource(zoneId as string) as string
    if Left(zoneId, 5) = "roon:" then return "roon"
    if Left(zoneId, 4) = "lms:" then return "lms"
    if Left(zoneId, 15) = "musicassistant:" then return "musicassistant"
    return ""
end function

function LibraryReady(state as object, now as integer, mutation as boolean) as boolean
    if state.readonly or state.bridge = "" or not HasZone(state.zones, state.zone) then return false
    if not state.online or state.pending or state.uncertain then return false
    if mutation and now - state.freshAt > 10000 then return false
    return LibraryTabs(LibraryZone(state.zones, state.zone)).Count() > 0
end function

function LibraryBody(req as object, zone as object) as dynamic
    operation = TextField(req, "operation")
    body = { zone_id: TextField(zone, "zone_id") }
    if operation = "browse"
        tabName = TextField(req, "tab")
        if not LibraryContains(LibraryTabs(zone), tabName) then return invalid
        body.action = tabName
        if tabName = "radio" or tabName = "favorites"
            body.action = "favorites"
            body.media_type = "tracks"
            if tabName = "radio" then body.media_type = "radio"
        end if
        location = TextField(req, "location")
        if Len(location) > 512 then return invalid
        if location <> ""
            body.location = location
            body.action = "browse"
            body.Delete("media_type")
        end if
        body.limit = 20
        body.offset = 0
        if IsNumericValue(req.offset)
            if req.offset < 0 or req.offset > 1000000 then return invalid
            body.offset = Int(req.offset)
        end if
    else if operation = "search"
        query = TextField(req, "query").Trim()
        if query = "" or Len(query) > 256 then return invalid
        body.query = query
    else if operation = "queue"
        ' The current unified contract implements queue read for MA, not Roon/LMS.
        if LibrarySource(body.zone_id) <> "musicassistant" then return invalid
        body.action = "read"
    else
        return invalid
    end if
    return body
end function

function LibraryEnvelopeError(body as dynamic, zone as string) as string
    if type(body) <> "roAssociativeArray" then return "Invalid library response — try again"
    if TextField(body.scope, "zone_id") <> zone then return "Zone changed. Refresh the library."
    outcome = TextField(body, "outcome")
    if outcome = "ok" or outcome = "accepted" then return ""
    detail = TextField(body.refusal, "detail")
    if detail = "" then detail = "Library request unavailable (" + outcome + ")"
    return detail
end function

function LibraryRows(body as object, operation as string) as dynamic
    data = body.data
    if operation = "search"
        items = data
    else
        if type(data) <> "roAssociativeArray" then return invalid
        items = data.items
    end if
    if type(items) <> "roArray" then return invalid
    if items.Count() > 500 then return invalid
    rows = []
    for each item in items
        title = TextField(item, "title")
        if operation = "queue" then title = TextField(item, "name")
        if title = "" then return invalid
        row = { title: Left(title, 300), subtitle: Left(TextField(item, "subtitle"), 300), location: TextField(item, "location"), ref: TextField(item, "ref"), image: TextField(item, "image") }
        if operation = "queue"
            row.location = ""
            row.ref = ""
        end if
        if Len(row.location) > 512 or Len(row.ref) > 512 then return invalid
        rows.Push(row)
    end for
    return rows
end function

function LibraryCanPlay(rows as dynamic, itemRef as string, action as string) as boolean
    if action <> "play" and action <> "queue" then return false
    if itemRef = "" or type(rows) <> "roArray" then return false
    for each row in rows
        if TextField(row, "ref") = itemRef then return true
    end for
    return false
end function

function LibraryNextOffset(data as dynamic, current as integer) as dynamic
    if type(data) <> "roAssociativeArray" then return invalid
    value = data.next_offset
    if not IsNumericValue(value) then return invalid
    if value <= current or value > 1000000 then return invalid
    return Int(value)
end function

function LibraryImageURL(bridge as string, image as string) as string
    prefix = "/api/collections/image?ref="
    if Left(image, Len(prefix)) <> prefix then return ""
    token = Mid(image, Len(prefix) + 1)
    if token = "" or Len(token) > 512 then return ""
    if not CreateObject("roRegex", "^[A-Za-z0-9%._~-]+$", "").IsMatch(token) then return ""
    root = NormalizeBridge(bridge)
    if root = "" then return ""
    return root + image
end function
