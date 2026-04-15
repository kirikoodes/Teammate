// TEAMMATE.POTO — WiFi Sensor
// M5StickC Plus2 / Bruce firmware
//
// Scans WiFi networks continuously and sends JSON over USB serial.
// TEAMMATE reads this data and maps it to POtO parameters in real time.
//
// Output format (one JSON line per scan):
//   {"n":12,"max":-42,"min":-88,"avg":-61,"var":14,"ch":5}
//
//   n   = number of networks found
//   max = strongest RSSI (dBm)
//   min = weakest RSSI (dBm)
//   avg = average RSSI (dBm)
//   var = standard deviation of RSSI values
//   ch  = number of distinct channels in use
//
// Install: copy this file to the Bruce SD card, run via Scripts menu.

var INTERVAL = 600; // ms between scans (lower = more reactive, more CPU)

while (true) {
    var nets = wifi.scan();

    if (nets && nets.length > 0) {
        var n    = nets.length;
        var sum  = 0;
        var max  = -999;
        var min  = 0;
        var chs  = {};

        for (var i = 0; i < n; i++) {
            var r = nets[i].rssi;
            sum += r;
            if (r > max) max = r;
            if (r < min) min = r;
            chs[nets[i].channel] = 1;
        }

        var avg = sum / n;
        var variance = 0;
        for (var i = 0; i < n; i++) {
            var diff = nets[i].rssi - avg;
            variance += diff * diff;
        }
        var std = Math.sqrt(variance / n);

        var ch_count = Object.keys(chs).length;

        var out = '{"n":' + n
                + ',"max":' + max
                + ',"min":' + min
                + ',"avg":' + Math.round(avg)
                + ',"var":' + Math.round(std)
                + ',"ch":'  + ch_count
                + '}';

        Serial.println(out);
    }

    delay(INTERVAL);
}
