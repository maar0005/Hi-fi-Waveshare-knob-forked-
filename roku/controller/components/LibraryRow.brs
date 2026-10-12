sub init()
    m.top.FindNode("rowArt").ObserveField("loadStatus", "rowArtLoaded")
end sub

sub rowContent()
    item = m.top.itemContent
    m.top.FindNode("rowArt").visible = false
    m.top.FindNode("rowArt").uri = ""
    m.top.FindNode("rowTitle").text = ""
    m.top.FindNode("rowSubtitle").text = ""
    if item = invalid then return
    m.top.FindNode("rowArt").uri = item.HDPosterUrl
    m.top.FindNode("rowTitle").text = item.title
    m.top.FindNode("rowSubtitle").text = item.description
    rowFocus()
end sub

sub rowFocus()
    focused = m.top.itemHasFocus and m.top.listHasFocus
    m.top.FindNode("rowFocusPlate").visible = focused
    m.top.FindNode("rowTitle").color = "0xEEE8DAFF"
    m.top.FindNode("rowSubtitle").color = "0xC0BAB0FF"
    if focused
        m.top.FindNode("rowTitle").color = "0x101012FF"
        m.top.FindNode("rowSubtitle").color = "0x34322EFF"
    end if
end sub

sub rowArtLoaded()
    poster = m.top.FindNode("rowArt")
    poster.visible = poster.uri <> "" and poster.loadStatus = "ready"
end sub
