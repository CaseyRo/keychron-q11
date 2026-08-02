// steuerhorn backlight sniffer — paste into the DevTools console on
// https://launcher.keychron.com BEFORE connecting the keyboard, then use
// the Launcher UI to toggle/adjust the backlight. Every HID report the
// page sends/receives is logged as hex. Copy the OUT lines that correspond
// to your backlight actions into keylight.py.
(() => {
  const log = (window.__steuerhornLog = window.__steuerhornLog || []);
  const hex = (d) => {
    const u8 = d instanceof DataView
      ? new Uint8Array(d.buffer, d.byteOffset, d.byteLength)
      : new Uint8Array(d.buffer ?? d);
    return [...u8].map((b) => b.toString(16).padStart(2, "0")).join(" ");
  };
  const note = (line) => {
    log.push(`${Date.now() % 100000} ${line}`);
    console.log(`[steuerhorn] ${line}`);
  };
  window.__steuerhornMark = (label) => note(`===== ${label} =====`);

  for (const fn of ["sendReport", "sendFeatureReport", "receiveFeatureReport"]) {
    const orig = HIDDevice.prototype[fn];
    HIDDevice.prototype[fn] = function (reportId, data) {
      note(`${fn} id=${reportId} ${data ? hex(data) : ""}`);
      return orig.call(this, reportId, data);
    };
  }

  // Log input reports + identity of already-granted devices.
  navigator.hid.getDevices().then((devices) =>
    devices.forEach((d) => {
      note(`device vid=0x${d.vendorId.toString(16)} pid=0x${d.productId.toString(16)} "${d.productName}" collections=${d.collections.map((c) => "0x" + (c.usagePage ?? 0).toString(16)).join(",")}`);
      d.addEventListener("inputreport", (e) => note(`inputreport id=${e.reportId} ${hex(e.data)}`));
    }),
  );

  console.log("[steuerhorn] armed. Mark actions with __steuerhornMark('backlight off'), then toggle in the UI. When done: copy(__steuerhornLog.join('\\n'))");
})();
