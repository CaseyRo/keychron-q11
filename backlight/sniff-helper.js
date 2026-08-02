// steuerhorn backlight sniffer — paste into the DevTools console on
// https://launcher.keychron.com BEFORE connecting the keyboard, then use
// the Launcher UI to toggle/adjust the backlight. Every HID report the
// page sends/receives is logged as hex. Copy the OUT lines that correspond
// to your backlight actions into keylight.py.
(() => {
  const hex = (d) => {
    const u8 = d instanceof DataView
      ? new Uint8Array(d.buffer, d.byteOffset, d.byteLength)
      : new Uint8Array(d.buffer ?? d);
    return [...u8].map((b) => b.toString(16).padStart(2, "0")).join(" ");
  };

  for (const fn of ["sendReport", "sendFeatureReport", "receiveFeatureReport"]) {
    const orig = HIDDevice.prototype[fn];
    HIDDevice.prototype[fn] = function (reportId, data) {
      console.log(`[steuerhorn] ${fn} id=${reportId}`, data ? hex(data) : "");
      return orig.call(this, reportId, data);
    };
  }

  // Log input reports from already-granted devices too.
  navigator.hid.getDevices().then((devices) =>
    devices.forEach((d) =>
      d.addEventListener("inputreport", (e) =>
        console.log(`[steuerhorn] inputreport id=${e.reportId}`, hex(e.data)),
      ),
    ),
  );

  console.log("[steuerhorn] sniffer armed — now do backlight things in the UI");
})();
