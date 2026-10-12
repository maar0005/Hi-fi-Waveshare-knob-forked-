function StartMemoryMonitoring(port as object) as object
    monitor = CreateObject("roAppMemoryMonitor")
    device = CreateObject("roDeviceInfo")
    device.SetMessagePort(port)
    device.EnableLowGeneralMemoryEvent(true)
    if monitor <> invalid
        monitor.SetMessagePort(port)
        monitor.EnableMemoryWarningEvent(true)
        limits = monitor.GetChannelMemoryLimit()
        print "HiPhi memory limits: "; limits
    end if
    return { monitor: monitor, device: device }
end function

sub UpdateMemoryPressure(memory as object, scene as object)
    percent = 0
    available = 0
    if memory.monitor <> invalid
        percent = memory.monitor.GetMemoryLimitPercent()
        available = memory.monitor.GetChannelAvailableMemory()
    end if
    level = memory.device.GetGeneralMemoryLevel()
    pressure = MemoryPressure(percent, available, level)
    if scene.HasField("memoryPressure") then scene.memoryPressure = pressure
end sub

function MemoryPressure(percent as integer, availableKb as integer, level as string) as boolean
    return percent >= 80 or (availableKb > 0 and availableKb < 16384) or level = "low" or level = "critical"
end function
