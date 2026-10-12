sub Main()
    m.failures = 0
    m.count = 0
    data = []
    data = []
    for each octet in [72,73,132,0,0,0,0,3,0,0,0,0,4,95,117,104,99,4,95,116,99,112,5,108,111,99,97,108,0,0,12,0,1,0,0,0,120,0,22,4,116,101,115,116,4,95,117,104,99,4,95,116,99,112,5,108,111,99,97,108,0,4,116,101,115,116,4,95,117,104,99,4,95,116,99,112,5,108,111,99,97,108,0,0,33,0,1,0,0,0,120,0,20,0,0,0,0,31,152,6,98,114,105,100,103,101,5,108,111,99,97,108,0,6,98,114,105,100,103,101,5,108,111,99,97,108,0,0,1,0,1,0,0,0,120,0,4,192,168,1,2]
        data[data.Count()] = octet
    end for
    records = DnsRecords(data)
    check(records.Count() = 3, "PTR SRV and A decoded")
    candidates = DiscoveryCandidates(records)
    check(candidates.Count() = 1 and candidates[0].bridge = "http://192.168.1.2:8088", "service target and actual port resolved")
    check(DiscoveryCandidates([records[0], records[1]]).Count() = 0, "missing address cannot guess an endpoint from packet sender")
    badPort = {name: records[1].name, kind: 33, target: records[1].target, port: 0}
    check(DiscoveryCandidates([records[0], badPort, records[2]]).Count() = 0, "zero advertised port rejected")
    records.Append(records)
    check(DiscoveryCandidates(records).Count() = 1, "duplicate announcements deduplicated")
    records[0].name = "_unrelated._tcp.local."
    check(DiscoveryCandidates([records[0], records[1], records[2]]).Count() = 0, "unrelated service cannot become bridge")
    data.Pop()
    check(DnsRecords(data).Count() = 0, "truncated record discarded atomically")
    data = []
    for each octet in [192,0]
        data[data.Count()] = octet
    end for
    check(DnsName(data, 0) = invalid, "compression cycle bounded")
    data = []
    for each octet in [192,255]
        data[data.Count()] = octet
    end for
    check(DnsName(data, 0) = invalid, "out-of-range pointer rejected")
    data = []
    for each octet in [3,97,98,99,0,192,0]
        data[data.Count()] = octet
    end for
    label = DnsName(data, 5)
    check(label.name = "abc." and label.nextPos = 7, "compression pointer preserves caller offset")
    query = DnsQuery("_uhc._tcp.local.")
    check(Dns16(query, 4) = 1 and DnsName(query, 12).name = "_uhc._tcp.local.", "legacy query encodes desired service")
    multicast = DnsQuery("_uhc._tcp.local.", false)
    check(Dns16(multicast, 0) = 0, "multicast query uses zero transaction ID")
    check(DnsRecords([0,0,128,0,0,0,255,255,0,0,0,0]).Count() = 0, "excessive record count bounded")
    if m.failures > 0 then stop
    print "PASS all discovery tests: "; m.count
end sub

sub check(value as boolean, label as string)
    m.count++
    if not value
        m.failures++
        print "FAIL: "; label
    end if
end sub
