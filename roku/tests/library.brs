sub Main()
    m.count = 0
    m.failures = 0
    zone = {zone_id: "roon:room", browse_supported: true, library_tabs: ["browse", "radio", "bogus", "browse"]}
    zone.library_tabs.Push({malformed: true})
    check(LibraryTabs(zone).Count() = 2, "unknown/duplicate tabs never invent UI actions")
    check(LibraryTabs({browse_supported: true}).Count() = 0, "old server without tab metadata fails closed")
    check(LibraryTabs({browse_supported: "true", library_tabs: ["browse"]}).Count() = 0, "malformed browse capability fails closed")
    body = LibraryBody({operation: "browse", tab: "radio"}, zone)
    check(body.action = "favorites" and body.media_type = "radio", "radio uses documented favorites/media_type contract")
    body = LibraryBody({operation: "browse", tab: "radio", location: "loc-folder", offset: 20}, zone)
    check(body.action = "browse" and body.location = "loc-folder" and body.media_type = invalid, "folder under radio becomes location browse")
    check(body.limit = 20 and body.offset = 20 and body.path = invalid, "paging uses durable location, never competing path")
    check(LibraryBody({operation: "browse", tab: "favorites"}, zone) = invalid, "unpublished tabs rejected on Task thread")
    check(LibraryBody({operation: "browse", tab: "browse", offset: -1}, zone) = invalid, "negative paging rejected")
    check(LibraryBody({operation: "search", query: "  Adele  "}, zone).query = "Adele", "search keeps explicit room and trims text")
    check(LibraryBody({operation: "search", query: " "}, zone) = invalid, "empty search rejected")
    check(LibraryBody({operation: "queue"}, zone) = invalid, "Roon unified queue read not advertised")
    check(LibraryBody({operation: "queue"}, {zone_id: "musicassistant:room"}).action = "read", "MA current queue uses read contract")
    check(LibraryNextOffset({next_offset: 20}, 0) = 20, "forward page accepted")
    check(LibraryNextOffset({next_offset: 0}, 0) = invalid, "nonprogressing paging rejected")
    check(LibraryNextOffset({next_offset: "20"}, 0) = invalid, "malformed paging rejected")
    env = libEnvelope("ok", [{title: "Album", location: "loc-album", ref: "ref-album"}, {title: "Track", ref: "ref-track"}])
    rows = LibraryRows(env, "browse")
    check(rows.Count() = 2 and rows[0].location <> "" and rows[0].ref <> "", "folder+playable item retains both choices")
    check(LibraryCanPlay(rows, "ref-track", "queue"), "server-minted current-row queue action")
    check(not LibraryCanPlay(rows, "invented", "play"), "cannot invent playable ref")
    check(not LibraryCanPlay(rows, "ref-track", "radio"), "unsupported action never expands from row ref")
    check(LibraryRows(libEnvelope("ok", [{subtitle: "missing title"}]), "browse") = invalid, "malformed row rejects page")
    env = {scope: {zone_id: "roon:room"}, outcome: "ok", data: [{title: "Search hit", ref: "s"}]}
    check(LibraryRows(env, "search")[0].ref = "s", "search array contract differs from collection page")
    env = {scope: {zone_id: "musicassistant:room"}, outcome: "ok", data: {items: [{name: "Queue track", ref: "forged", location: "forged"}]}}
    rows = LibraryRows(env, "queue")
    check(rows[0].title = "Queue track" and rows[0].ref = "" and rows[0].location = "", "queue rows never manufacture playback refs")
    check(LibraryEnvelopeError({outcome: "ok", scope: {zone_id: "elsewhere"}}, "roon:room") <> "", "cross-room envelope rejected")
    check(LibraryEnvelopeError({outcome: "unsupported", scope: {zone_id: "roon:room"}, refusal: {detail: "No library"}}, "roon:room") = "No library", "HTTP200 refusal preserves server detail")
    taskTests()
    if m.failures = 0 then print "PASS all library task tests: "; m.count
end sub

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub

function libEnvelope(outcome as string, items as object) as object
    return {outcome: outcome, scope: {zone_id: "roon:room"}, data: {items: items, breadcrumbs: [{title: "Albums", location: "loc-albums"}], next_offset: 20}}
end function

sub taskFixture()
    m.clock = {value: 1000, TotalMilliseconds: function() as integer
        return m.value
    end function}
    m.encode = function(value as string) as string
        return value
    end function
    m.state = NewClientState(false)
    ResetClient(m.state, "http://bridge:8088", "roon:room")
    m.state.zones = [{zone_id: "roon:room", browse_supported: true, library_tabs: ["browse", "playlists", "radio"]}]
    AcceptPlaying(m.state, m.state.session, m.state.zone, {zone_id: m.state.zone, is_playing: false, is_play_allowed: true}, 1000)
    m.top = {}
    m.pending = {}
    m.sse = invalid
    m.libraryGeneration = 0
    m.libraryLatest = 0
    resetLibrary()
    m.testX = libTransfer(51)
    m.transportFactory = function() as object
        return m.testX
    end function
end sub

function libTransfer(id as integer) as object
    return {id: id, body: "", postCount: 0, cancelCount: 0, started: true,
        GetIdentity: function() as integer
            return m.id
        end function,
        AddHeader: sub(name as string, value as string)
        end sub,
        AsyncPostFromString: function(body as string) as boolean
            m.body = body
            m.postCount++
            return m.started
        end function,
        AsyncGetToString: function() as boolean
            return m.started
        end function,
        AsyncCancel: sub()
            m.cancelCount++
        end sub}
end function

function libResponse(id as integer, code as integer, body as object) as object
    return {id: id, code: code, body: FormatJson(body),
        GetSourceIdentity: function() as integer
            return m.id
        end function,
        GetResponseCode: function() as integer
            return m.code
        end function,
        GetString: function() as string
            return m.body
        end function}
end function

function browseReq(id as integer) as object
    return {kind: "library", operation: "browse", tab: "browse", session: m.state.session, zone: m.state.zone, requestId: id}
end function

function playReq(id as integer, ref as string) as object
    return {kind: "library_play", ref: ref, action: "play", session: m.state.session, zone: m.state.zone, requestId: id}
end function

sub taskTests()
    taskFixture()
    handleRequest(browseReq(1))
    wire = ParseJson(m.testX.body)
    check(m.testX.postCount = 1 and wire.zone_id = m.state.zone and wire.action = "browse", "actual Task sends documented pinned browse body")
    oldEntry = m.pending["51"]
    oldTransfer = m.testX
    m.testX = libTransfer(52)
    handleRequest(browseReq(2))
    check(oldTransfer.cancelCount = 1 and not m.pending.DoesExist("51"), "new same-room navigation cancels old page transfer")
    m.top.libraryResult = invalid
    libraryResponse(oldEntry, libEnvelope("ok", [{title: "Old", ref: "old"}]))
    check(m.top.libraryResult = invalid and m.libraryRows.Count() = 0, "late same-room generation cannot install old refs")
    handleRequest(browseReq(1))
    check(m.testX.postCount = 1, "late queued navigation cannot replace newer generation")
    handleResponse(libResponse(52, 200, libEnvelope("ok", [{title: "Album", ref: "album"}])))
    check(m.top.libraryResult.status = "ok" and m.top.libraryResult.data.rows[0].ref = "album", "actual response path installs current page")
    check(m.top.libraryResult.data.nextOffset = 20, "actual response forwards next page")
    m.testX = libTransfer(53)
    handleRequest(playReq(1, "album"))
    check(m.testX.postCount = 0, "old page click cannot use current item ref")
    handleRequest(playReq(2, "forged"))
    check(m.testX.postCount = 0, "dispatcher rejects unminted ref")
    handleRequest(playReq(2, "album"))
    check(m.state.pending and m.testX.postCount = 1, "play sent once under shared mutation lock")
    check(ParseJson(m.testX.body).ref = "album" and ParseJson(m.testX.body).zone_id = "roon:room", "play trigger uses exact ref and pinned zone")
    handleRequest(playReq(2, "album"))
    check(m.testX.postCount = 1, "held/repeated play cannot double POST")
    handleResponse(libResponse(53, 200, {outcome: "accepted", scope: {zone_id: "roon:room"}}))
    check(m.top.libraryResult.status = "accepted" and m.state.uncertain, "accepted play acknowledgement still requires state reconciliation")
    handleRequest(playReq(2, "album"))
    check(m.testX.postCount = 1, "unreconciled accepted mutation prevents repeated play")
    AcceptPlaying(m.state, m.state.session, m.state.zone, {zone_id: m.state.zone, is_playing: true}, 1000)
    m.testX = libTransfer(54)
    handleRequest(playReq(2, "album"))
    expireRequests(10000)
    check(m.testX.cancelCount = 1 and m.testX.postCount = 1 and m.state.uncertain, "play timeout cancels and locks without replay")
    check(m.pending.Count() = 0 and m.top.libraryResult.status = "error", "unknown mutation shows actionable uncertainty")
    taskFixture()
    handleRequest(browseReq(1))
    handleResponse(libResponse(51, 200, libEnvelope("ok", [{title: "Album", ref: "expired"}])))
    m.testX = libTransfer(52)
    handleRequest(playReq(1, "expired"))
    handleResponse(libResponse(52, 200, {outcome: "invalid", scope: {zone_id: m.state.zone}, refusal: {reason: "unknown_target", detail: "Expired ref"}}))
    check(m.top.libraryResult.status = "refresh" and m.libraryRows.Count() = 0, "expired-ref HTTP200 refusal clears play refs and asks for refresh")
    check(m.testX.postCount = 1 and m.state.uncertain, "expired ref is never auto-replaced/replayed")
    taskFixture()
    handleRequest(browseReq(1))
    handleResponse(libResponse(51, 200, {outcome: "unsupported", scope: {zone_id: m.state.zone}, refusal: {detail: "Provider unavailable"}}))
    check(m.top.libraryResult.status = "error" and m.state.online, "browse refusal is not playback disconnection")
    m.testX = libTransfer(52)
    handleRequest(browseReq(2))
    oldSession = m.state.session
    handleRequest({kind: "configure", zone: "roon:other", bridge: "http://other:8088"})
    m.top.libraryResult = invalid
    handleResponse(libResponse(52, 200, libEnvelope("ok", [{title: "Old room", ref: "old"}])))
    check(m.state.session <> oldSession and m.top.libraryResult = invalid and m.libraryRows.Count() = 0, "bridge/room change discards page and playable refs")
    taskFixture()
    handleRequest(browseReq(1))
    m.state.zones = []
    m.top.libraryResult = invalid
    handleResponse(libResponse(51, 200, libEnvelope("ok", [{title: "Removed room", ref: "old"}])))
    check(m.top.libraryResult = invalid and m.libraryRows.Count() = 0, "removed pinned room rejects in-flight browse result")
    taskFixture()
    m.state.readonly = true
    handleRequest(browseReq(1))
    handleRequest(playReq(1, "album"))
    check(m.testX.postCount = 0, "screensaver dispatcher refuses library reads and mutations")
    taskFixture()
    handleRequest(browseReq(1))
    expireRequests(10000)
    check(m.state.online and not m.state.uncertain and m.top.libraryResult.status = "error", "browse timeout only fails library view")
    taskFixture()
    handleRequest(browseReq(1))
    handleResponse(libResponse(51, 200, libEnvelope("ok", [{title: "Album", ref: "album"}])))
    m.clock.value = 12000
    m.testX = libTransfer(52)
    handleRequest(playReq(1, "album"))
    check(m.testX.postCount = 0 and m.nextRead = 0, "stale playback state refreshes without triggering play")
end sub
