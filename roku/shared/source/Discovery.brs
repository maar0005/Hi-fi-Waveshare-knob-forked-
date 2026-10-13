' Bounded DNS decoder: no recursion, at most 32 labels/pointers per name.
function Dns16(data as object, cursor as integer) as integer
    return data[cursor] * 256 + data[cursor + 1]
end function

function DnsName(data as object, cursor as integer) as dynamic
    name = ""
    finish = -1
    seen = {}
    for hop = 0 to 31
        if cursor < 0 or cursor >= data.Count() then return invalid
        if seen.DoesExist(cursor.ToStr()) then return invalid
        seen[cursor.ToStr()] = true
        n = data[cursor]
        if n = 0
            if finish < 0 then finish = cursor + 1
            return {name: LCase(name), nextPos: finish}
        end if
        if n >= 192
            if cursor + 1 >= data.Count() then return invalid
            if finish < 0 then finish = cursor + 2
            cursor = (n - 192) * 256 + data[cursor + 1]
        else
            if n > 63 or cursor + n >= data.Count() then return invalid
            for i = 1 to n
                name += Chr(data[cursor + i])
            end for
            name += "."
            if Len(name) > 255 then return invalid
            cursor += n + 1
        end if
    end for
    return invalid
end function

function DnsQuery(service as string, legacy = true as boolean) as object
    data = []
    for each octet in [72,73,0,0,0,1,0,0,0,0,0,0]
        data[data.Count()] = octet
    end for
    if not legacy
        data[0] = 0: data[1] = 0
    end if
    for each label in service.Split(".")
        if label <> ""
            data[data.Count()] = Len(label)
            for i = 1 to Len(label)
                data[data.Count()] = Asc(Mid(label, i, 1))
            end for
        end if
    end for
    data[data.Count()] = 0
    data[data.Count()] = 0: data[data.Count()] = 12 ' PTR
    data[data.Count()] = 0: data[data.Count()] = 1 ' IN, legacy unicast reply to ephemeral port
    return data
end function

function DnsRecords(data as object) as object
    records = []
    if data.Count() < 12 or data.Count() > 9000 then return records
    if (data[2] and 128) = 0 then return records
    questions = Dns16(data, 4)
    count = Dns16(data, 6) + Dns16(data, 8) + Dns16(data, 10)
    if questions > 16 or count > 128 then return records
    cursor = 12
    for q = 1 to questions
        label = DnsName(data, cursor)
        if label = invalid then return []
        cursor = label.nextPos + 4
        if cursor > data.Count() then return []
    end for
    for r = 1 to count
        label = DnsName(data, cursor)
        if label = invalid then return []
        cursor = label.nextPos
        if cursor + 10 > data.Count() then return []
        kind = Dns16(data, cursor)
        cls = Dns16(data, cursor + 2) and 32767
        alive = data[cursor+4] + data[cursor+5] + data[cursor+6] + data[cursor+7] > 0
        size = Dns16(data, cursor + 8)
        cursor += 10
        last = cursor + size
        if last > data.Count() then return []
        if cls = 1 and alive
            record = {name: label.name, kind: kind}
            if kind = 1 and size = 4
                record.ip = data[cursor].ToStr() + "." + data[cursor+1].ToStr() + "." + data[cursor+2].ToStr() + "." + data[cursor+3].ToStr()
                records.Push(record)
            else if kind = 12 or kind = 33
                start = cursor
                if kind = 33 then start += 6
                if start < last
                    target = DnsName(data, start)
                    if target = invalid then return []
                    if target.nextPos > last then return []
                    record.target = target.name
                    if kind = 33 then record.port = Dns16(data, cursor + 4)
                    records.Push(record)
                end if
            end if
        end if
        cursor = last
    end for
    return records
end function

function DiscoveryCandidates(records as object) as object
    results = []
    seen = {}
    for each ptr in records
        if ptr.kind = 12 and (ptr.name = "_uhc._tcp.local." or ptr.name = "_roonknob._tcp.local.")
            for each srv in records
                if srv.kind = 33 and srv.name = ptr.target and srv.port > 0
                    for each addr in records
                        if addr.kind = 1 and addr.name = srv.target
                            bridge = NormalizeBridge(addr.ip + ":" + srv.port.ToStr())
                            if bridge <> "" and not seen.DoesExist(bridge)
                                seen[bridge] = true
                                results.Push({bridge: bridge, name: Left(ptr.target, Len(ptr.target) - Len(ptr.name) - 1)})
                                if results.Count() >= 8 then return results
                            end if
                        end if
                    end for
                end if
            end for
        end if
    end for
    return results
end function
