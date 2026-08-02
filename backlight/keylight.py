#!/usr/bin/env python3
"""Day/night backlight control for the Keychron Q11 Ultra 8K.

STATUS: skeleton. The Ultra series runs Keychron's ZMK fork and speaks a
proprietary HID protocol to launcher.keychron.com — there is no published
host-control tooling, so the report bytes below must be captured once with
backlight/sniff-helper.js (see README).

usage: keylight.py on|off|auto
"""

import datetime
import sys

import hid  # pip install hidapi

VID = 0x3434  # Keychron
PID = None  # TODO(sniff): Q11 Ultra product id (Q6 Ultra is 0x1260)
USAGE_PAGE = 0xFF60  # TODO(sniff): confirm the vendor collection Launcher uses

# TODO(sniff): fill with (report_id, [bytes...]) captured from the Launcher.
REPORTS = {
    "on": None,
    "off": None,
}

# ponytail: fixed hours, edit here; sunrise/sunset needs a location + lib
DAY_STARTS, DAY_ENDS = 8, 18


def send(action: str) -> None:
    report = REPORTS[action]
    if report is None:
        sys.exit(f"no bytes captured yet for {action!r} — run the sniff session first")
    report_id, data = report
    dev_path = next(
        (d["path"] for d in hid.enumerate(VID, PID or 0)
         if d["usage_page"] == USAGE_PAGE),
        None,
    )
    if dev_path is None:
        sys.exit("keyboard not found (check PID/usage page, and 2.4G vs wired)")
    dev = hid.device()
    dev.open_path(dev_path)
    try:
        dev.write(bytes([report_id, *data]))
    finally:
        dev.close()


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else "auto"
    if action == "auto":
        action = "off" if DAY_STARTS <= datetime.datetime.now().hour < DAY_ENDS else "on"
    if action not in REPORTS:
        sys.exit(__doc__)
    send(action)


if __name__ == "__main__":
    main()
