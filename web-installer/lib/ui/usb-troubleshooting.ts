/**
 * Shared OS-specific USB / udev / driver troubleshooting markup for all routes
 * that pair with a Pixel over WebUSB (`/install`, `/install/update`,
 * `/install/verify-device`, `/install/recover`).
 *
 * Pure HTML emitter: zero DOM, zero inline handlers, zero style attributes,
 * zero remote URLs (D-006 CSP safe).
 */

export function usbTroubleshootingHtml(): string {
  return [
    `<details class="usb-troubleshooting" data-guide="usb-troubleshooting">`,
    `<summary>USB / driver troubleshooting (Linux, Windows, macOS, Android)</summary>`,
    `<div class="usb-troubleshooting__body">`,
    `<p>If the Pixel does not appear in the browser&#39;s USB picker or fails to claim the interface, check the host setup for your operating system:</p>`,
    `<dl class="usb-os-list">`,
    `<dt>Linux (udev &amp; fwupd)</dt>`,
    `<dd><ul>`,
    `<li>Add a udev rule for Google Pixel vendor ID <code class="mono">18d1</code> in <code class="mono">/etc/udev/rules.d/51-android.rules</code> (<code class="mono">SUBSYSTEM==&quot;usb&quot;, ATTR{idVendor}==&quot;18d1&quot;, MODE=&quot;0666&quot;, GROUP=&quot;plugdev&quot;</code>), then run <code class="mono">sudo udevadm control --reload-rules &amp;&amp; sudo udevadm trigger</code>.</li>`,
    `<li>Stop <code class="mono">fwupd</code> if it claims the fastboot interface: <code class="mono">sudo systemctl stop fwupd.service</code>.</li>`,
    `<li>Stop any local <code class="mono">adb</code> daemon holding the USB handle: <code class="mono">adb kill-server</code>.</li>`,
    `</ul></dd>`,
    `<dt>Windows (Google USB Driver / WinUSB)</dt>`,
    `<dd><ul>`,
    `<li>Install the Google USB Driver (or Windows Update optional driver updates while the Pixel is in Fastboot Mode) so Windows binds <code class="mono">Android Bootloader Interface</code> (<code class="mono">WinUSB</code>).</li>`,
    `<li>If Device Manager shows a warning icon on <code class="mono">Android</code> or <code class="mono">Pixel</code>, update the driver to <code class="mono">Android Bootloader Interface</code>.</li>`,
    `<li>Close any local <code class="mono">adb.exe</code> or <code class="mono">fastboot.exe</code> processes (<code class="mono">adb kill-server</code>) before opening the browser picker.</li>`,
    `</ul></dd>`,
    `<dt>macOS</dt>`,
    `<dd><ul>`,
    `<li>No separate driver is required. If prompted by macOS to allow the USB accessory to connect, choose <strong>Allow</strong>.</li>`,
    `<li>Stop any local <code class="mono">adb</code> daemon (<code class="mono">adb kill-server</code>) and close other browser tabs or IDE device monitors using USB.</li>`,
    `<li>Prefer a direct USB-C cable/port; unpowered USB-C hubs can drop enumeration after <code class="mono">reboot-bootloader</code>.</li>`,
    `</ul></dd>`,
    `<dt>Browser &amp; Android-to-Android (OTG)</dt>`,
    `<dd><ul>`,
    `<li>Use a Chromium-based browser (Chrome, Chromium, Edge, or Brave) in a normal window — not Private/Incognito, Firefox, Safari, or Tor Browser.</li>`,
    `<li>When connecting from another Android phone over USB-C, turn off <strong>Desktop site</strong> mode so the browser does not drop the USB session.</li>`,
    `</ul></dd>`,
    `</dl>`,
    `</div>`,
    `</details>`,
  ].join("");
}
