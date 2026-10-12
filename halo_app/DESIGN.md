# HALO Touch interaction and visual system

The native surface inherits HiPhi's existing dark artwork-led UI, production Lato 22px/Noto Sans 28px fonts and playback controls. This pass replaces navigation behavior, not the HiPhi brand.

Artwork is the home view. Artwork has no buttons, labels or rings. Tapping artwork reveals playback controls and Menu, which opens named destinations. Back navigates the collection hierarchy or returns to Menu. Home consistently returns to artwork. Zones are actions rather than peer pages in a swipe loop.

Task views use the round display's central rectangle: heading at the top, Back/Home below it, scrollable content in the middle, and explicit playback actions above the lower rim. Lists scroll vertically. Artwork-rich collections use a horizontal center-snapping carousel with neighbouring cards visible. Album covers are 132×132 RGB565. Single-row truncation protects long labels; folder/selection state survives Back.

Buttons show immediate pressed feedback. Blue-gray focus mirrors rotary selection; the pointer remains live during dragging and LVGL suppresses clicks when scrolling wins. Touch and the knob manipulate the same content. The knob adjusts volume only on Artwork/Now playing. Settings brightness uses a horizontal slider; connectivity updates its row without resetting scroll.

The task background is near-black (`#080808`), button surfaces are `#252525`/`#181818`, focused rows are `#39434b`, pressed surfaces are `#526573`, text is `#eeeeee`, secondary text is `#b8c4cd`, and slider indicator/knob use `#a9c6dc`/`#d7e8f4`. Motion comes from native scrolling, inertia and snapping, with animated rotary focus movement. There are no decorative transitions or global directional mode gestures.

This system was inspected through round-masked production-widget host renders and native pointer tests. Those establish source/layout behavior, not physical touch feel. Keep hardware observations in issue #277 and PR #278, tied to the exact artifact.

Tapping the Now playing background returns directly to artwork; transport buttons and Menu retain their own actions. Zones are selected through Menu. Settings includes About (firmware, device address and HiPhi site) and Factory reset, which requires an explicit confirmation and erases local saved configuration before restarting into setup. Back cancels reset. Playback controls are reached by tapping artwork, rather than duplicated in Menu.
