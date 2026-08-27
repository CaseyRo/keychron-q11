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

## Settings channel (`a7`)

Captured 2026-08-27 the same way as the RGB channel. Subcommand in byte 1;
every response echoes `a7 <sub>` and carries a status byte at index 2
(`00` = ok), so a reply is matched on bytes 0–1 and validated on byte 2.

| Sub  | Exchange | Meaning |
| ---- | -------- | ------- |
| `05` | `a7 05 ff` → `a7 05 00 01 0a 32` | debounce: byte 4 = press-down ms (`0a`=10), byte 5 = reset ms (`32`=50) |
| `0b` | `a7 0b` → `a7 0b 00 58 02 20 1c` | unidentified device/status block |
| `0d` | `a7 0d` → `a7 0d 00 40 1f 7f W 00 40 1f 7f G 00 7d 00 40 40 01` | settings read-back; **W** = wired polling index, **G** = 2.4G polling index |
| `0e` | `a7 0e <wired> <2.4G>` → `a7 0e 00 <2.4G>` | **set polling rate — both transports at once** |

Polling-rate index counts *down* from 8000 (index = log2(8000/Hz)):

| Hz    | 8000 | 4000 | 2000 | 1000 | 500  | 250  | 125  |
| ----- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| index | `00` | `01` | `02` | `03` | `04` | `05` | `06` |

`00`–`03` observed directly by setting each rate and re-reading `a7 0d`;
`04`–`06` extrapolated from the series and **not verified**.

There is **no mode byte**. `a7 0e` carries both indices positionally —
byte 2 = wired, byte 3 = 2.4G — and rewrites both on every call. This was
mis-read at first as `<index> <mode>`, which fits the three wired captures and
breaks on the fourth; the argument bytes always equal the pair `a7 0d` reads
back:

| set        | OUT           | `a7 0d` → W, G |
| ---------- | ------------- | -------------- |
| wired→1000 | `a7 0e 03 02` | 03, 02 |
| wired→8000 | `a7 0e 00 02` | 00, 02 |
| wired→4000 | `a7 0e 01 02` | 01, 02 |
| 2.4G→1000  | `a7 0e 01 03` | 01, 03 |

⚠️ **Read `a7 0d` first and echo the byte you are not changing.** Sending a
single index — `a7 0e 03` to "set 1000" — leaves byte 3 at `00` and silently
forces the *other* transport to 8000Hz, the worst case for battery.

Bluetooth is fixed at 125Hz in firmware, has no UI control, and does not
appear in this command at all.

## Battery (receiver command family `b0`–`bc`)

The keyboard exposes **no HID battery usage page** — usages present are
`0x01, 0x07, 0x08, 0x09, 0x0c`, with no `0x06` battery-strength and no
`0x84/0x85` power page — so macOS reports nothing natively and the Q11 never
appears in `AppleDeviceManagementHIDEventService`. The Launcher does not help
either: its bundle carries battery code (`getBattery`, `watchBattery`,
`batteryLevel`, `chargeFlag`, `BATTERY_CHANGE=4`) but no screen renders battery
for this board, so it never sends the query and a sniff captures nothing.

The receiver answers anyway. `csutcliff/keychron-battery-dkms` (GPL-2.0) is a
Linux HID driver for **`3434:d028` — the same Ultra-Link 8K receiver** — and
documents the exchange:

| Field | Value |
| ----- | ----- |
| Interface | **4** — here that is usage page `0xffc1` |
| Request | **feature report** id `0xb3`, byte 1 = `0x06` (STATUS), 64 bytes |
| Response | report id `0xb4`, byte 1 echoes `0x06` |
| Battery | **absolute byte offset 20**, valid when `<= 100` |

The driver sends the request as `SET_REPORT`(feature) on the control endpoint
and reads the answer from the **interrupt IN** endpoint of the same interface,
polling every 5 minutes and treating a miss as normal (a sleeping wireless
device just does not answer).

### Tested here: the receiver does not answer (2026-08-27)

Tried against `3434:d028` on macOS via hidapi, on all three vendor collections
(`0xffc1`/iface 4, `0xff60`/iface 2, `0x8c`/iface 3), as both a feature report
and a plain output report:

- `get_feature_report(0xb4)` returns `b4 06 00 00 …` — the report exists and
  the command echoes, but every payload byte including offset 20 is zero.
- After sending `b3 06`, the interrupt endpoint is **silent** on all three.

This is not a permissions problem and not Launcher interference. Both were
ruled out: `keylight.py status` performs the same `dev.read()` on `0xff60` and
returns the current effect, with the Launcher closed and Input Monitoring
granted. Reads work; the device simply does not reply to `b3 06`.

Most likely the receiver populates this slot only for the Keychron M5 mouse —
the device the driver was written for — and a keyboard-paired dongle leaves it
empty. The `b*` family is the *receiver's* command space (`b2 00 00` returns
VID/PID, see above), so it is plausibly mouse-specific throughout.

Untested routes, most promising first:

1. **Bluetooth.** The Ultra runs ZMK, which serves the standard BLE Battery
   Service (`0x180F`); macOS reads that natively for BLE HID and would show it
   without any code here. Costs polling rate — BT is pinned to 125Hz.
2. **Cable, querying the keyboard's own PID `0x12b2`** rather than the
   receiver, in case the battery lives on the keyboard's vendor interface.
3. ZMK Studio's HID protocol, if Keychron's fork exposes it.

⚠️ Do **not** blind-scan the `a7` or `b*` subcommand space hunting for it.
`a7 0e` is a setter, so a probe of the form `a7 XX 00 00` can silently rewrite
a real setting — polling rate included.
