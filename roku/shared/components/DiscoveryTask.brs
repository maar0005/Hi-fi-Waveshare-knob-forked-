sub init()
    m.top.functionName = "discover"
end sub

sub discover()
    generation = m.top.generation
    port = CreateObject("roMessagePort")
    sock = CreateObject("roDatagramSocket")
    sock.SetMessagePort(port)
    bind = CreateObject("roSocketAddress")
    bind.SetAddress("0.0.0.0:5353")
    target = CreateObject("roSocketAddress")
    target.SetAddress("224.0.0.251:5353")
    sock.SetReuseAddr(true)
    legacy = not sock.SetAddress(bind)
    if not legacy then legacy = not sock.JoinGroup(target)
    if legacy
        sock.Close()
        sock = CreateObject("roDatagramSocket")
        sock.SetMessagePort(port)
        bind.SetAddress("0.0.0.0:0")
    end if
    bound = true
    if legacy then bound = sock.SetAddress(bind)
    if not bound or not sock.SetSendToAddress(target)
        sock.Close()
        m.top.result = {generation: generation, bridges: [], notice: "Discovery unavailable. Enter the bridge address."}
        return
    end if
    sock.SetMulticastTTL(255)
    sock.NotifyReadable(true)
    records = []
    clock = CreateObject("roTimespan")
    nextQuery = 0
    while clock.TotalMilliseconds() < 4000
        if clock.TotalMilliseconds() >= nextQuery
            for each service in ["_uhc._tcp.local.", "_roonknob._tcp.local."]
                encoded = DnsQuery(service, legacy)
                query = CreateObject("roByteArray")
                for i = 0 to encoded.Count() - 1
                    query[i] = encoded[i]
                end for
                sock.Send(query, 0, query.Count())
            end for
            nextQuery += 1500
        end if
        msg = Wait(100, port)
        if sock.IsReadable()
            bytes = CreateObject("roByteArray")
            bytes[9000] = 0
            count = sock.Receive(bytes, 0, 9000)
            if count > 0 and count <= 9000
                packet = []
                for offset = 0 to count - 1
                    packet.Push(bytes[offset])
                end for
                parsed = DnsRecords(packet)
                for each record in parsed
                    if records.Count() < 256 then records.Push(record)
                end for
            end if
        end if
    end while
    if not legacy then sock.DropGroup(target)
    sock.Close()
    candidates = DiscoveryCandidates(records)
    verified = []
    ' At most eight candidates; each read has a one-second deadline.
    for each candidate in candidates
        x = CreateObject("roUrlTransfer")
        x.SetMessagePort(port)
        x.SetUrl(candidate.bridge + "/zones")
        if x.AsyncGetToString()
            timer = CreateObject("roTimespan")
            while timer.TotalMilliseconds() < 1000
                event = Wait(100, port)
                if type(event) = "roUrlEvent"
                    if event.GetSourceIdentity() = x.GetIdentity()
                        if event.GetResponseCode() = 200
                            body = ParseJson(event.GetString())
                            if type(body) = "roAssociativeArray"
                                if type(body.zones) = "roArray" then verified.Push(candidate)
                            end if
                        end if
                        exit while
                    end if
                end if
            end while
            x.AsyncCancel()
        end if
    end for
    notice = "Pick a music bridge"
    if verified.Count() = 0 then notice = "No bridges found. Enter an address or try again."
    m.top.result = {generation: generation, bridges: verified, notice: notice}
end sub
