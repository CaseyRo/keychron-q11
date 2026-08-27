// keychron-q11 HID sniffer — paste into the DevTools console on
// https://launcher.keychron.com BEFORE connecting the keyboard, then use
// the Launcher UI to perform the action you want to capture. Every HID
// report the page sends/receives is logged as hex.
//
// OUT lines (sendReport/sendFeatureReport) are the commands to replay from
// Python; IN lines (inputreport) are the keyboard's answers — battery level
// and other read-backs live there, so both directions matter.
(() => {
  const log = (window.__q11Log = window.__q11Log || []);
  const hex = (d) => {
    const u8 = d instanceof DataView
      ? new Uint8Array(d.buffer, d.byteOffset, d.byteLength)
      : new Uint8Array(d.buffer ?? d);
    return [...u8].map((b) => b.toString(16).padStart(2, "0")).join(" ");
  };
  const note = (line) => {
    log.push(`${Date.now() % 100000} ${line}`);
    console.log(`[keychron-q11] ${line}`);
  };
  window.__q11Mark = (label) => note(`===== ${label} =====`);

  for (const fn of ["sendReport", "sendFeatureReport", "receiveFeatureReport"]) {
    const orig = HIDDevice.prototype[fn];
    HIDDevice.prototype[fn] = function (reportId, data) {
      note(`${fn} id=${reportId} ${data ? hex(data) : ""}`);
      return orig.call(this, reportId, data);
    };
  }

  // Log input reports. A device granted DURING this session — the normal case,
  // since this file is pasted before connecting — never appears in
  // getDevices() at arm time, so hook requestDevice and the connect event too.
  // Without this the capture holds every question and not one answer, which is
  // fine for setting the backlight and useless for reading a battery level.
  const attach = (d) => {
    if (d.__q11Attached) return;
    d.__q11Attached = true;
    note(`device vid=0x${d.vendorId.toString(16)} pid=0x${d.productId.toString(16)} "${d.productName}" collections=${d.collections.map((c) => "0x" + (c.usagePage ?? 0).toString(16)).join(",")}`);
    d.addEventListener("inputreport", (e) => note(`inputreport id=${e.reportId} ${hex(e.data)}`));
  };

  navigator.hid.getDevices().then((devices) => devices.forEach(attach));
  navigator.hid.addEventListener("connect", (e) => attach(e.device));
  const origRequest = navigator.hid.requestDevice.bind(navigator.hid);
  navigator.hid.requestDevice = (...args) =>
    origRequest(...args).then((devices) => (devices.forEach(attach), devices));

  console.log("[keychron-q11] armed. Mark actions with __q11Mark('battery'), then act in the UI. When done: copy(__q11Log.join('\\n'))");
})();
