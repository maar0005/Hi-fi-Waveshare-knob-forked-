# Home Assistant lights on the HiPhi Dial

The HiPhi Dial (Waveshare ESP32-S3-Knob-Touch-LCD-1.8, `idf_app`) can dim up to four Home Assistant lights. It talks to Home Assistant directly over its REST API; the Unified Hi-Fi Control bridge is not involved. Other targets do not show Lights.

## Set up

1. In Home Assistant, open your profile, then **Security**, and create a **long-lived access token**. Copy it now; Home Assistant shows it only once.
2. Find each light's entity ID under **Settings → Devices & services → Entities**, for example `light.sofa_lamp`. Only `light.*` entities are accepted. To dim several lamps together, create a Home Assistant light group and use its entity ID.
3. Open the Dial's web settings at `http://<dial-ip>/` (the address is under Settings → About on the Dial) and choose **Home Assistant lights**.
4. Enter the Home Assistant address, paste the token, and fill in up to four entity IDs. A display name is optional; without one the Dial uses the light's Home Assistant name.
5. Save. The change applies immediately; no restart is needed.

Address forms: `homeassistant.local`, `192.168.1.10` or `ha.lan:8123` become `http://…:8123`. `https://` addresses keep their own port and are checked against the built-in certificate bundle, so a Nabu Casa URL works. A self-signed certificate does not; use the local `http://` address instead.

Leave the token field blank to keep the saved token while changing other fields. **Clear** removes the Home Assistant configuration. Factory reset also erases it.

## Use

Tap the artwork, then **Menu → Lights**. Menu scrolls to show Settings below Lights.

- **One light:** opens its dimmer directly.
- **Several lights:** a list shows each light's state; tap one to dim it.

On the dimmer:

| Action | What it does |
|--------|--------------|
| Turn the knob | Brightness up/down in 5% steps; turning down to 0% switches the light off |
| Drag the arc | Set brightness directly |
| Turn on / Turn off | Toggle; turning on restores the light's previous brightness |
| Back | Return to the list (or Menu with one light) |

The knob controls brightness only on the Lights screens; on Artwork and Now playing it still controls volume. Changes appear on the Dial immediately and are sent in the background; a fast turn sends the latest value rather than every step. The Dial re-reads the light every 10 seconds while the screen is open, so changes from a wall switch or the Home Assistant app show up.

On/off-only lights (no brightness support) show On/Off; the knob turns them on or off.

## Troubleshooting

| Message | Meaning |
|---------|---------|
| Token rejected. Check web settings. | Home Assistant returned 401/403. Create a new token and paste it again. |
| Light not found in Home Assistant | The entity ID does not exist. Check spelling under Entities. |
| Home Assistant unreachable | No connection within 4 seconds. Check the address and that the Dial and Home Assistant share a network. |
| Unavailable in Home Assistant | Home Assistant reports the light as unavailable (for example, a powered-off bulb). |

## Security

The token is stored in the Dial's device storage, like the Wi-Fi password, and is sent only to the configured Home Assistant address. The web settings page never displays it. Anyone who can reach the Dial's web settings on your network can replace the configuration. Revoke the token in Home Assistant if the Dial is lost or given away.

## Roon playlists

Playlists need no extra setup. On the Dial choose **Menu → Library → Playlists**, open a playlist, and choose **Play** or **Queue**. Playback goes to the zone selected under Menu → Zone. Library browsing requires a Unified Hi-Fi Control bridge version that provides the collections API.
