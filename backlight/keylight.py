#!/usr/bin/env python3
# /// script
# dependencies = ["hidapi"]
# ///
"""Day/night backlight control for the Keychron Q11 Ultra 8K.

Speaks the VIA v3 custom-values protocol that Keychron's ZMK fork exposes
on the vendor HID collection (usage page 0xFF60) — captured 2026-08-02 from
launcher.keychron.com, documented in docs/protocol.md.

usage: uv run keylight.py on|off|auto|status
"""

import datetime
import pathlib
import sys

import hid

VID = 0x3434  # Keychron (wired keyboard or Ultra-Link 8K receiver alike)
USAGE_PAGE = 0xFF60  # VIA-style vendor collection

CMD_SET, CMD_GET, CMD_SAVE = 0x07, 0x08, 0x09
CH_RGB = 0x03  # rgb-matrix channel
VAL_EFFECT = 0x02  # 0 = off

DEFAULT_ON_EFFECT = 0x10  # Casey's effect as of 2026-08-02; overridden by state file
STATE = pathlib.Path.home() / ".local/state/keychron-q11-effect"

# ponytail: fixed hours, edit here; sunrise/sunset needs a location + lib
DAY_STARTS, DAY_ENDS = 8, 18


def open_device() -> "hid.device":
    info = next(
        (d for d in hid.enumerate(VID) if d["usage_page"] == USAGE_PAGE), None
    )
    if info is None:
        sys.exit("no Keychron 0xFF60 interface found (keyboard off / dongle unplugged?)")
    dev = hid.device()
    dev.open_path(info["path"])
    return dev


def xfer(dev, *payload: int) -> None:
    dev.write(bytes([0x00, *payload]).ljust(33, b"\x00"))  # report id 0 + 32 bytes


def get_effect(dev) -> int | None:
    # An open Launcher tab reads the same interface and can steal our
    # response — re-ask a few times instead of trusting one round-trip.
    for _ in range(3):
        xfer(dev, CMD_GET, CH_RGB, VAL_EFFECT)
        for _ in range(10):  # skip unrelated interleaved reports
            resp = dev.read(32, timeout_ms=300)
            if resp and resp[:3] == [CMD_GET, CH_RGB, VAL_EFFECT]:
                return resp[3]
            if not resp:
                break
    return None


def set_effect(dev, effect: int) -> None:
    xfer(dev, CMD_SET, CH_RGB, VAL_EFFECT, effect)
    xfer(dev, CMD_SAVE, CH_RGB)


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else "auto"
    if action == "auto":
        action = "off" if DAY_STARTS <= datetime.datetime.now().hour < DAY_ENDS else "on"

    dev = open_device()
    try:
        current = get_effect(dev)
        if action == "status":
            print(f"effect={current}")
            return
        if action == "off":
            if current:  # remember what to restore, but never remember "off"
                STATE.parent.mkdir(parents=True, exist_ok=True)
                STATE.write_text(str(current))
            target = 0
        elif action == "on":
            try:
                target = int(STATE.read_text())
            except (FileNotFoundError, ValueError):
                target = DEFAULT_ON_EFFECT
        else:
            sys.exit(__doc__)
        set_effect(dev, target)
        readback = get_effect(dev)
        print(f"backlight {action}: effect {current} -> {readback}")
        if readback is None:
            print("verify inconclusive (Launcher tab open?) — set was sent", file=sys.stderr)
        elif readback != target:
            sys.exit(f"verify failed: wanted {target}, keyboard reports {readback}")
    finally:
        dev.close()


if __name__ == "__main__":
    main()
