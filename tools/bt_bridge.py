#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pont BT/BLE -> OSC pour TEAMMATE.POTO.

Lit le M5StickC Plus 2 (sous ESP32 Bus Pirate) en USB serie pendant un scan
Bluetooth, en extrait les appareils detectes, et envoie au norns :

    /sniff/bt  mac(str)  name(str)  rssi(int dBm)

TEAMMATE sonifie alors la PRESENCE autour de toi : chaque appareil (telephone,
montre, oreillettes...) devient un "personnage" musical reconnaissable a sa MAC,
le RSSI pilote la distance/modulation, et un nouvel appareil declenche un accent.

Ou le lancer :
  - sur ton ordi (Stick branche en USB sur l'ordi) -> --host <IP_du_norns>
  - sur le norns lui-meme (Stick branche sur le norns) -> --host 127.0.0.1
Le norns ecoute l'OSC sur le port 10111 par defaut.

Dependances :  pip install pyserial python-osc

Exemples :
  py tools/bt_bridge.py --port COM5 --host 192.168.0.17      # depuis Windows
  py tools/bt_bridge.py --sim   --host 192.168.0.17          # SANS materiel : faux appareils
  py tools/bt_bridge.py --port COM5 --raw                    # juste afficher la sortie brute (pour caler le parser)

VIE PRIVEE : on n'envoie au norns que des metadonnees (MAC tronquee possible,
nom public d'annonce, RSSI). Aucune connexion n'est etablie : c'est de l'ecoute
passive d'annonces BLE, comme ton scan WiFi.
"""

import argparse
import re
import sys
import time

try:
    from pythonosc.udp_client import SimpleUDPClient
except ImportError:
    sys.exit("python-osc manquant :  pip install python-osc")


# --- Parser : a CALER sur la sortie reelle du Bus Pirate (mode BT) ---------
# Colle-moi 5-10 lignes brutes (via --raw) et j'ajuste cette regex au format exact.
# Pour l'instant : on capture une MAC (AA:BB:CC:DD:EE:FF), un RSSI (entier negatif,
# souvent precede de "RSSI" ou entre parentheses), et un nom optionnel.
MAC_RE  = re.compile(r"([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})")
RSSI_RE = re.compile(r"(-?\d{1,3})\s*dBm|RSSI[:=\s]*(-?\d{1,3})|\(\s*(-?\d{1,3})\s*\)")
NAME_RE = re.compile(r"(?:name|nom)[:=\s]+([^\s,;|]+)", re.IGNORECASE)


def parse_bt(line):
    """Parse une ligne de scan BT -> (mac, name, rssi) ou None.
    Tolerant : tant qu'on trouve une MAC, on renvoie un event (rssi -120 par defaut)."""
    line = line.strip()
    m = MAC_RE.search(line)
    if not m:
        return None
    mac = m.group(1).upper()

    rssi = -120
    r = RSSI_RE.search(line)
    if r:
        val = next((g for g in r.groups() if g is not None), None)
        if val is not None:
            try:
                rssi = int(val)
            except ValueError:
                pass

    name = ""
    n = NAME_RE.search(line)
    if n:
        name = n.group(1)

    return (mac, name, rssi)


def run_serial(args, osc):
    try:
        import serial  # pyserial
    except ImportError:
        sys.exit("pyserial manquant :  pip install pyserial")

    print(f"[bt_bridge] OSC -> {args.host}:{args.osc_port}  | serie {args.port}@{args.baud}")
    while True:
        try:
            ser = serial.Serial(args.port, args.baud, timeout=1)
        except Exception as e:
            print(f"[bt_bridge] port indisponible ({e}); nouvel essai dans 3 s")
            time.sleep(3)
            continue
        try:
            while True:
                raw = ser.readline()
                if not raw:
                    continue
                line = raw.decode("utf-8", "replace")
                if args.raw:
                    print("  <", line.rstrip())
                    continue
                ev = parse_bt(line)
                if ev:
                    mac, name, rssi = ev
                    osc.send_message("/sniff/bt", [str(mac), str(name), int(rssi)])
                    print(f"[bt] {mac}  name={name!r}  rssi={rssi}")
        except Exception as e:
            print(f"[bt_bridge] erreur serie ({e}); reouverture")
            try:
                ser.close()
            except Exception:
                pass
            time.sleep(2)


def run_sim(args, osc):
    """Faux appareils, pour tester la chaine OSC -> son SANS le Stick."""
    print(f"[bt_bridge] SIMULATION  OSC -> {args.host}:{args.osc_port}  (Ctrl+C pour arreter)")
    fake = [
        ("AA:BB:CC:11:22:33", "iPhone de Lea"),
        ("DE:AD:BE:EF:00:01", "Galaxy Buds"),
        ("12:34:56:78:9A:BC", "Mi Band 7"),
        ("F0:0D:CA:FE:BA:BE", ""),               # appareil sans nom (frequent en BLE)
        ("00:1A:7D:DA:71:13", "JBL Flip"),
    ]
    i = 0
    # un compteur deterministe pour faire varier le RSSI sans random
    while True:
        mac, name = fake[i % len(fake)]
        rssi = -45 - ((i * 17) % 70)             # oscille entre -45 et -114 dBm
        osc.send_message("/sniff/bt", [str(mac), str(name), int(rssi)])
        print(f"[sim] {mac}  name={name!r}  rssi={rssi}")
        i += 1
        time.sleep(args.sim_interval)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", help="port serie du Stick (ex: COM5, /dev/ttyACM0)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--host", default="127.0.0.1",
                    help="IP du norns (127.0.0.1 si le pont tourne sur le norns)")
    ap.add_argument("--osc-port", type=int, default=10111)
    ap.add_argument("--sim", action="store_true",
                    help="mode demo : envoie de faux appareils, sans materiel")
    ap.add_argument("--sim-interval", type=float, default=1.2,
                    help="secondes entre deux faux appareils (mode --sim)")
    ap.add_argument("--raw", action="store_true",
                    help="affiche la sortie serie brute sans parser (pour caler la regex)")
    args = ap.parse_args()

    osc = SimpleUDPClient(args.host, args.osc_port)

    if args.sim:
        run_sim(args, osc)
    elif args.port:
        run_serial(args, osc)
    else:
        sys.exit("Donne --port COMx (mode reel) ou --sim (mode demo).")


if __name__ == "__main__":
    main()
