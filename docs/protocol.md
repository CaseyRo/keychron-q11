# Keychron Q11 Ultra 8K — host HID protocol notes

Captured 2026-08-02 by monkey-patching `HIDDevice.prototype.sendReport` on
launcher.keychron.com (`backlight/sniff-helper.js`). As far as we know this is
unpublished territory for the ZMK-based Ultra series.

## The headline

**Keychron's ZMK fork implements the VIA v3 custom-values protocol** for
lighting — the Launcher bundle literally uses `id_qmk_rgb_matrix_effect` /
`id_qmk_rgb_matrix_brightness` value keys. Everything QMK/VIA-shaped about
raw HID applies, despite the firmware being ZMK.

## Transport

- Receiver: "Keychron Ultra-Link 8K", VID `0x3434`, PID `0xd028` (2.4G mode).
  Exposes three HID collections: usage pages `0xffc1`, **`0xff60`** (the VIA
  vendor collection — talk to this one), `0x8c`.
- Reports: report id `0`, 32-byte payloads, response echoes the request header.
- Launcher device id (their `vpId`): 875827890 ("Keychron Q11 Ultra 8K Knob ISO",
  4 layers). Firmware metadata: `https://launcher.keychron.com/vapi/v2/product/875827890`.
- `a3 00 ff …` both directions = Launcher keepalive/poll, ignore.
- `a8 …` / `b2 …` = other state queries (indication colors, capability probes).

## RGB matrix channel (channel `0x03`)

| Byte 0 (cmd) | Meaning |
| ------------ | ------- |
| `0x07` | set value |
| `0x08` | get value (response: same header + value) |
| `0x09` | save channel to flash |

Byte 1 = channel (`0x03` = rgb matrix), byte 2 = value id, bytes 3+ = value.

| Value id | Meaning | Observed |
| -------- | ------- | -------- |
| `0x01` | brightness 0–255 | `fe`→254; slider steps `e6 cc b3 99 80` |
| `0x02` | effect index | `0x00` = **off**, `0x10` = effect #16 (in use here) |
| `0x03` | effect speed | `9a` = 154 |
| `0x04` | color (hue, sat) | `00 ff` |

Underglow (`uBright`, `uEffect` in Launcher's model) is tracked separately —
value ids not yet captured; sniff an underglow toggle if we ever need it.

## Sequences

- Backlight off: `07 03 02 00` → `09 03`
- Backlight on (effect 16): `07 03 02 10` → `09 03`
- Read current effect: `08 03 02` → response `08 03 02 <effect>`
