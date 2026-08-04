#!/usr/bin/env python3
# /// script
# dependencies = ["hidapi"]
# ///
"""Day/night backlight control for the Keychron Q11 Ultra 8K.

Speaks the VIA v3 custom-values protocol that Keychron's ZMK fork exposes
on the vendor HID collection (usage page 0xFF60) — captured 2026-08-02 from
launcher.keychron.com, documented in docs/protocol.md.

`auto` asks Home Assistant for the current house mode and falls back to the
clock when HA is unconfigured or unreachable. The launchd agent runs `auto`
on a poll, so the keyboard is re-corrected after a reconnect or re-pair
rather than drifting until the next scheduled flip.

usage: uv run keylight.py on|off|auto|status|selftest
"""

import datetime
import json
import os
import pathlib
import subprocess
import sys
import urllib.request

import hid

VID = 0x3434  # Keychron (wired keyboard or Ultra-Link 8K receiver alike)
USAGE_PAGE = 0xFF60  # VIA-style vendor collection

CMD_SET, CMD_GET, CMD_SAVE = 0x07, 0x08, 0x09
CH_RGB = 0x03  # rgb-matrix channel
VAL_EFFECT = 0x02  # 0 = off

DEFAULT_ON_EFFECT = 0x10  # fallback when no state file exists yet
STATE = pathlib.Path.home() / ".local/state/keychron-q11-effect"

# Home Assistant house mode drives `auto`. HA_URL lives in the conf file;
# the token lives in the login keychain (`security add-generic-password
# -s keychron-q11-ha -a "$USER" -w "$TOKEN"`) so no secret sits in a dotfile.
# No HA? Leave the conf file out and the clock below takes over.
CONF = pathlib.Path.home() / ".config/keychron-q11.env"
HA_ENTITY = "input_select.house_mode"
HA_KEYCHAIN_SERVICE = "keychron-q11-ha"
# House modes bright enough (or empty enough) to not want a lit keyboard.
# Everything else — morning, evening, night, guest, custom — lights up.
MODES_DARK_OFF = {"day", "away"}

# Fallback only, used when HA can't be reached.
DAY_STARTS, DAY_ENDS = 8, 18


def ha_url() -> str | None:
    try:
        for line in CONF.read_text().splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "HA_URL":
                return value.strip().strip("\"'").rstrip("/") or None
    except FileNotFoundError:
        pass
    return None


def ha_token() -> str | None:
    # Env first so this stays testable over ssh, where the login keychain
    # isn't reachable. The launchd agent runs in the GUI session, where it is.
    if env := os.environ.get("HA_TOKEN"):
        return env
    out = subprocess.run(
        ["security", "find-generic-password", "-s", HA_KEYCHAIN_SERVICE, "-w"],
        capture_output=True, text=True,
    )
    return out.stdout.strip() or None


def house_mode() -> str | None:
    """Current HA house mode, or None if unconfigured/unreachable."""
    url, token = ha_url(), ha_token()
    if not (url and token):
        return None
    req = urllib.request.Request(
        f"{url}/api/states/{HA_ENTITY}",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.load(resp)["state"]
    except Exception as exc:
        # Laptop off the tailnet, HA rebooting, token rotated — any of these
        # must degrade to the clock, never take the backlight down with them.
        print(f"house mode unavailable ({exc}); using clock", file=sys.stderr)
        return None


def auto_action(mode: str | None, hour: int) -> str:
    if mode is not None:
        return "off" if mode in MODES_DARK_OFF else "on"
    return "off" if DAY_STARTS <= hour < DAY_ENDS else "on"


def selftest() -> None:
    assert auto_action("day", 3) == "off"  # HA wins over the clock
    assert auto_action("away", 22) == "off"
    assert auto_action("night", 12) == "on"
    assert auto_action("evening", 12) == "on"
    assert auto_action("morning", 12) == "on"
    assert auto_action("guest", 12) == "on"  # unknown-ish modes light up
    assert auto_action(None, 8) == "off"  # clock fallback, boundaries
    assert auto_action(None, 17) == "off"
    assert auto_action(None, 18) == "on"
    assert auto_action(None, 7) == "on"
    print("selftest ok")


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
    if action == "selftest":
        return selftest()
    if action == "auto":
        mode = house_mode()
        action = auto_action(mode, datetime.datetime.now().hour)
        print(f"auto: house mode {mode or '(clock)'} -> {action}")

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
        if current == target:
            # Polling every few minutes, and set_effect writes the keyboard's
            # flash — don't burn a write cycle re-asserting what's already set.
            print(f"backlight {action}: already effect {target}")
            return
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
