#!/usr/bin/env python3
# /// script
# dependencies = ["pyobjc-framework-MediaPlayer", "pyobjc-framework-Cocoa"]
# ///
"""The office's music as this Mac's Now Playing.

macOS shows one Now Playing entry, and anything that reads it — Bartender's
Top Shelf music widget, Control Center, the keyboard's play key — then shows
and controls the office player as if it played here. This process publishes
what Home Assistant says the office is playing and turns play/pause back into
a Home Assistant call. It plays no audio itself; macOS does not ask it to.

Runs as a launchd agent (install.sh --nowplaying). Which players count as
"the office" is OFFICE_PLAYERS in ~/.config/keychron-q11.env, the same list
the router's right knob uses.

usage: uv run nowplaying.py            run until killed
       uv run nowplaying.py selftest
"""

import json
import os
import pathlib
import subprocess
import sys
import urllib.request

# HA_URL and OFFICE_PLAYERS live in the conf file; the token lives in the login
# keychain (`security add-generic-password -s keychron-q11-ha -a "$USER" -w`)
# so no secret sits in a dotfile. Atrium reads the same two.
CONF = pathlib.Path.home() / ".config/keychron-q11.env"
HA_KEYCHAIN_SERVICE = "keychron-q11-ha"


def conf(key: str) -> str | None:
    try:
        for line in CONF.read_text().splitlines():
            name, _, value = line.partition("=")
            if name.strip() == key:
                return value.strip().strip("\"'") or None
    except FileNotFoundError:
        pass
    return None


def ha_url() -> str | None:
    url = conf("HA_URL")
    return url.rstrip("/") if url else None


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

POLL = 5  # seconds; polled, like everything else here that could be watched


def template(players: list[str]) -> str:
    """Jinja for HA: the office player that plays, else one that is paused."""
    return (
        "{% set ps = expand(" + json.dumps(players) + ") %}"
        "{% set p = (ps | selectattr('state','eq','playing') | list"
        " + ps | selectattr('state','eq','paused') | list) | first %}"
        "{{ {'id': p.entity_id, 'state': p.state,"
        " 'title': p.attributes.media_title, 'artist': p.attributes.media_artist,"
        " 'album': p.attributes.media_album_name} | tojson if p else '' }}"
    )


def parse(text: str | None) -> dict | None:
    """HA's answer as a player dict, or None for nothing playing/unreachable."""
    try:
        player = json.loads(text or "")
    except ValueError:
        return None
    return player if isinstance(player, dict) and player.get("id") else None


def ha(path: str, body: dict) -> str | None:
    url, token = ha_url(), ha_token()
    if not (url and token):
        return None
    req = urllib.request.Request(
        url + path, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        # short: this runs on the main thread, and a play key waits behind it
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.read().decode()
    except Exception as exc:
        print(f"home assistant unavailable ({exc})", file=sys.stderr)
        return None


def selftest() -> None:
    assert parse(None) is None and parse("") is None and parse("nonsense") is None
    assert parse("[]") is None and parse('{"state": "playing"}') is None
    p = parse('{"id": "media_player.x", "state": "paused", "title": null}')
    assert p and p["state"] == "paused" and p["title"] is None
    t = template(["media_player.a", "media_player.b"])
    assert '["media_player.a", "media_player.b"]' in t and "tojson" in t
    print("selftest ok")


def main() -> None:
    if sys.argv[1:] == ["selftest"]:
        return selftest()
    players = [p.strip() for p in (conf("OFFICE_PLAYERS") or "").split(",") if p.strip()]
    if not players:
        sys.exit("OFFICE_PLAYERS is not set in ~/.config/keychron-q11.env")

    import MediaPlayer as MP
    from AppKit import NSApplication, NSApplicationActivationPolicyAccessory
    from Foundation import NSTimer

    app = NSApplication.sharedApplication()
    app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)  # no Dock icon
    center = MP.MPNowPlayingInfoCenter.defaultCenter()
    query = template(players)
    last = {"id": players[0], "shown": None}

    def refresh(_timer=None) -> None:
        player = parse(ha("/api/template", {"template": query}))
        if player == last["shown"]:
            return
        last["shown"] = player
        if not player:
            center.setNowPlayingInfo_(None)
            center.setPlaybackState_(MP.MPNowPlayingPlaybackStateStopped)
            return
        last["id"] = player["id"]
        playing = player["state"] == "playing"
        center.setNowPlayingInfo_({
            MP.MPMediaItemPropertyTitle: player.get("title") or "Office",
            MP.MPMediaItemPropertyArtist: player.get("artist") or "",
            MP.MPMediaItemPropertyAlbumTitle: player.get("album") or "",
            MP.MPNowPlayingInfoPropertyIsLiveStream: True,  # no scrubber
            MP.MPNowPlayingInfoPropertyPlaybackRate: 1.0 if playing else 0.0,
        })
        center.setPlaybackState_(
            MP.MPNowPlayingPlaybackStatePlaying if playing
            else MP.MPNowPlayingPlaybackStatePaused
        )

    def command(service: str):
        def handle(_event) -> int:
            ok = ha("/api/services/media_player/" + service, {"entity_id": last["id"]})
            refresh()
            return (MP.MPRemoteCommandHandlerStatusSuccess if ok is not None
                    else MP.MPRemoteCommandHandlerStatusCommandFailed)
        return handle

    commands = MP.MPRemoteCommandCenter.sharedCommandCenter()
    for cmd, service in (
        (commands.playCommand(), "media_play"),
        (commands.pauseCommand(), "media_pause"),
        (commands.togglePlayPauseCommand(), "media_play_pause"),
    ):
        cmd.setEnabled_(True)
        cmd.addTargetWithHandler_(command(service))

    refresh()
    NSTimer.scheduledTimerWithTimeInterval_repeats_block_(POLL, True, refresh)
    app.run()


if __name__ == "__main__":
    main()
