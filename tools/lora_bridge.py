#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pont LoRa -> OSC pour TEAMMATE.POTO.

Lit un module LoRa USB en serie (testé sur REYAX RYLR896/RYLR998, qui sortent
des trames du type :  +RCV=<addr>,<len>,<data>,<rssi>,<snr>) et envoie au norns :

    /lora/rx  sender(str)  rssi(int dBm)  snr(float)  len(int)  text(str)
    /lora/tx  dest(str)    len(int)            (quand TU envoies, voir plus bas)

Où le lancer :
  - sur le norns lui-même (module branché en USB sur le norns) -> --host 127.0.0.1
  - sur ton ordi (module branché sur l'ordi) -> --host <IP_du_norns>
Le norns écoute l'OSC sur le port 10111 par défaut.

Dépendances :  pip install pyserial python-osc

Exemples :
  python3 lora_bridge.py --port /dev/ttyUSB0 --host 127.0.0.1
  python3 lora_bridge.py --port COM5 --host 192.168.0.17    # depuis Windows

DÉCHIFFREMENT : si tes messages sont chiffrés (tes propres capteurs), déchiffre
dans decode_payload() ci-dessous AVANT d'envoyer le texte. Les clés restent ici,
jamais sur le norns. Pour du trafic que tu ne possèdes pas, n'envoie que les
métadonnées (rssi/snr/len) et laisse le texte vide.
"""

import argparse
import sys
import time

try:
    import serial  # pyserial
except ImportError:
    sys.exit("pyserial manquant :  pip install pyserial")
try:
    from pythonosc.udp_client import SimpleUDPClient
except ImportError:
    sys.exit("python-osc manquant :  pip install python-osc")


def decode_payload(raw_bytes):
    """Transforme les octets bruts du message en texte sonifiable.
    Par défaut : décodage UTF-8 tolérant. Branche ton déchiffrement AES ici
    pour tes propres devices (les clés ne quittent pas ce script)."""
    try:
        return raw_bytes.decode("utf-8", "replace")
    except Exception:
        return raw_bytes.hex()


def parse_rylr(line):
    """Parse une trame REYAX RYLR :  +RCV=<addr>,<len>,<data>,<rssi>,<snr>
    Retourne (sender, rssi, snr, length, text) ou None si non reconnue."""
    line = line.strip()
    if not line.startswith("+RCV="):
        return None
    body = line[len("+RCV="):]
    # data peut contenir des virgules -> on découpe par les bornes connues
    head, sep, tail = body.partition(",")          # addr
    addr = head
    length_str, sep, rest = tail.partition(",")     # len
    try:
        length = int(length_str)
    except ValueError:
        return None
    # data = les <length> octets ; rssi,snr = les deux derniers champs
    data = rest[:length]
    after = rest[length:].lstrip(",")
    parts = after.split(",")
    rssi = int(parts[0]) if len(parts) > 0 and parts[0].lstrip("-").isdigit() else -120
    try:
        snr = float(parts[1]) if len(parts) > 1 else 0.0
    except ValueError:
        snr = 0.0
    text = decode_payload(data.encode("utf-8", "replace"))
    return (addr, rssi, snr, length, text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True, help="port série du module (ex: /dev/ttyUSB0, COM5)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--host", default="127.0.0.1", help="IP du norns (127.0.0.1 si le pont tourne sur le norns)")
    ap.add_argument("--osc-port", type=int, default=10111)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    osc = SimpleUDPClient(args.host, args.osc_port)
    print(f"[lora_bridge] OSC -> {args.host}:{args.osc_port}  | série {args.port}@{args.baud}")

    while True:
        try:
            ser = serial.Serial(args.port, args.baud, timeout=1)
        except Exception as e:
            print(f"[lora_bridge] port indisponible ({e}); nouvel essai dans 3 s")
            time.sleep(3)
            continue
        try:
            while True:
                raw = ser.readline()
                if not raw:
                    continue
                line = raw.decode("utf-8", "replace")
                if args.verbose:
                    print("  <", line.strip())
                msg = parse_rylr(line)
                if msg:
                    sender, rssi, snr, length, text = msg
                    osc.send_message("/lora/rx", [str(sender), int(rssi), float(snr), int(length), str(text)])
                    print(f"[rx] from={sender} rssi={rssi} snr={snr} len={length} text={text!r}")
        except Exception as e:
            print(f"[lora_bridge] erreur série ({e}); réouverture")
            try:
                ser.close()
            except Exception:
                pass
            time.sleep(2)


if __name__ == "__main__":
    main()
