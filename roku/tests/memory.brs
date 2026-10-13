sub Main()
    if MemoryPressure(79, 20000, "normal") then stop
    if not MemoryPressure(80, 20000, "normal") then stop
    if not MemoryPressure(0, 1000, "normal") then stop
    if not MemoryPressure(0, 0, "critical") then stop
    if MemoryPressure(0, 0, "normal") then stop
    print "PASS all memory pressure tests: 5"
end sub
