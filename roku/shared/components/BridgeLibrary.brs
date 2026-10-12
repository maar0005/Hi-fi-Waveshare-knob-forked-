sub resetLibrary()
    if m.libraryLatest = invalid then m.libraryLatest = 0
    if m.libraryGeneration = invalid then m.libraryGeneration = 0
    m.libraryGeneration++
    m.libraryRows = []
    m.libraryRequest = invalid
    cancelLibraryReads()
end sub

sub cancelLibraryReads()
    for each key in m.pending.Keys()
        if m.pending[key].role = "library"
            m.pending[key].x.AsyncCancel()
            m.pending.Delete(key)
        end if
    end for
end sub

sub libraryResult(requestId as integer, status as string, notice as string, data as dynamic)
    m.top.libraryResult = { requestId: requestId, session: m.state.session, zone: m.state.zone, status: status, notice: notice, data: data }
end sub

sub requestLibrary(req as object)
    if req.session <> m.state.session or req.zone <> m.state.zone then return
    if not IsNumericValue(req.requestId) then return
    if m.libraryLatest = invalid then m.libraryLatest = 0
    if req.requestId < m.libraryLatest then return
    if req.kind <> "library_play" then m.libraryLatest = req.requestId
    if req.kind = "library_close"
        resetLibrary()
        return
    end if
    if not LibraryReady(m.state, m.clock.TotalMilliseconds(), req.kind = "library_play")
        libraryResult(req.requestId, "error", "Library unavailable — check connection and listening room", invalid)
        m.nextRead = 0
        return
    end if
    if req.kind = "library_play"
        if m.libraryRequest = invalid then return
        if req.requestId <> m.libraryRequest.requestId then return
        if LibrarySource(m.state.zone) = "" then return
        if not LibraryCanPlay(m.libraryRows, TextField(req, "ref"), TextField(req, "action"))
            libraryResult(req.requestId, "error", "Item unavailable — refresh the list", invalid)
            return
        end if
        m.state.pending = true
        m.state.notice = "Asking your room to play…"
        meta = { requestId: req.requestId, operation: "play", action: req.action, generation: m.libraryGeneration }
        startTransfer("libraryCommand", "/api/play_ref", { zone_id: m.state.zone, ref: req.ref, action: req.action }, meta)
        publish()
        return
    end if
    body = LibraryBody(req, LibraryZone(m.state.zones, m.state.zone))
    if body = invalid
        libraryResult(req.requestId, "error", "This library action is unavailable for the listening room", invalid)
        return
    end if
    resetLibrary()
    m.libraryRequest = req
    path = "/api/collections"
    if req.operation = "search" then path = "/api/search"
    if req.operation = "queue" then path = "/api/queue"
    meta = { requestId: req.requestId, operation: req.operation, generation: m.libraryGeneration, offset: body.offset }
    startTransfer("library", path, body, meta)
end sub

sub libraryResponse(entry as object, body as object)
    meta = entry.meta
    error = LibraryEnvelopeError(body, m.state.zone)
    if entry.role = "libraryCommand"
        m.state.pending = false
        m.state.uncertain = true
        invalidatePlaying()
        if error <> ""
            status = "error"
            if TextField(body.refusal, "reason") = "ref_expired" or TextField(body.refusal, "reason") = "unknown_target" then status = "refresh"
            ' All invalid refs require a new deliberate selection; never retry a mutation.
            if TextField(body, "outcome") = "invalid" then status = "refresh"
            m.libraryRows = []
            m.state.notice = "Playback not accepted — checking your music"
            if meta.generation = m.libraryGeneration then libraryResult(meta.requestId, status, error, invalid)
        else
            m.state.notice = "Waiting for playback…"
            if meta.action = "queue" then m.state.notice = "Checking your queue…"
            if meta.generation = m.libraryGeneration then libraryResult(meta.requestId, "accepted", m.state.notice, { action: meta.action })
        end if
        publish()
        return
    end if
    if meta.generation <> m.libraryGeneration then return
    if not HasZone(m.state.zones, m.state.zone) then return
    if error <> ""
        libraryResult(meta.requestId, "error", error, invalid)
        return
    end if
    rows = LibraryRows(body, meta.operation)
    if rows = invalid
        libraryResult(meta.requestId, "error", "Invalid library results — try again", invalid)
        return
    end if
    m.libraryRows = rows
    nextOffset = invalid
    breadcrumbs = []
    if meta.operation = "browse"
        nextOffset = LibraryNextOffset(body.data, meta.offset)
        if type(body.data.breadcrumbs) = "roArray" then breadcrumbs = body.data.breadcrumbs
    end if
    libraryResult(meta.requestId, "ok", "", { rows: rows, nextOffset: nextOffset, breadcrumbs: breadcrumbs })
end sub

sub libraryFailed(entry as object)
    meta = entry.meta
    notice = "Library unavailable — press OK to retry"
    if entry.role = "libraryCommand"
        m.state.pending = false
        m.state.uncertain = true
        m.state.notice = "Checking whether playback changed…"
        invalidatePlaying()
        notice = "Still checking playback. Wait before trying again."
        publish()
    end if
    if meta.generation = m.libraryGeneration then libraryResult(meta.requestId, "error", notice, invalid)
end sub
