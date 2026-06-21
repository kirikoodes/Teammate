#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pont Meshtastic -> OSC pour TEAMMATE.POTO  (LilyGO T-Deck Plus & co).

Le T-Deck Plus tourne sous Meshtastic : il déchiffre déjà tes messages (clés de
canal côté Meshtastic) et expose une API. Ce pont s'y connecte (USB série OU
WiFi/TCP), et renvoie au norns le MÊME OSC que le reste :

    /lora/rx  sender(str)  rssi(int dBm)  snr(float)  len(int)  text(str)
    /lora/tx  dest(str)    len(int)            (tes propres messages sortants)

=> Côté norns : RIEN à changer. Page LORA, comportements, tout est déjà câblé.

Dépendances :  pip install meshtastic python-osc

Connexion USB (T-Deck branché sur le norns ou l'ordi) :
    python3 lora_bridge_meshtastic.py --host 127.0.0.1
    python3 lora_bridge_meshtastic.py --port COM7 --host 192.168.0.17   # Windows

Connexion WiFi/TCP (Meshtastic "WiFi" activé sur le T-Deck) :
    python3 lora_bridge_meshtastic.py --tcp 192.168.0.42 --host 127.0.0.1

Le norns écoute l'OSC sur le port 10111 par défaut.

NB : le déchiffrement est géré par Meshtastic via les clés de CANAL configurées
sur le T-Deck — aucune clé ne transite par le norns. Tu ne sonifies que les
canaux que tu peux lire (les tiens / ceux dont tu as la clé).
"""

import argparse
import sys
import time

try:
    from pythonosc.udp_client import SimpleUDPClient
except ImportError:
    sys.exit("python-osc manquant :  pip install python-osc")
try:
    from pubsub import pub
    import meshtastic
    import meshtastic.serial_interface
    import meshtastic.tcp_interface
except ImportError:
    sys.exit("meshtastic manquant :  pip install meshtastic")


osc = None          # client OSC (créé dans main)
my_num = None       # numéro de notre propre noeud (pour distinguer TX de RX)


def sender_name(interface, num):
    """Nom lisible d'un noeud à partir de son numéro, sinon !hexid."""
    try:
        by_num = getattr(interface, "nodesByNum", None) or {}
        node = by_num.get(num)
        if node:
            user = node.get("user", {})
            return user.get("longName") or user.get("shortName") or ("!%08x" % num)
    except Exception:
        pass
    return ("!%08x" % num) if isinstance(num, int) else str(num)


def on_receive(packet, interface):
    """Appelé par Meshtastic à chaque paquet reçu."""
    try:
        decoded = packet.get("decoded", {})
        if decoded.get("portnum") != "TEXT_MESSAGE_APP":
            return                                   # on ne sonifie que les messages texte
        text = decoded.get("text", "")
        frm  = packet.get("from")
        rssi = int(packet.get("rxRssi", -120) or -120)
        snr  = float(packet.get("rxSnr", 0.0) or 0.0)
        name = sender_name(interface, frm)

        if my_num is not None and frm == my_num:
            # message émis par NOUS -> appel (ouvre la fenêtre appel-réponse)
            dest = packet.get("to", "broadcast")
            osc.send_message("/lora/tx", [str(dest), int(len(text))])
            print(f"[tx] to={dest} len={len(text)} text={text!r}")
        else:
            osc.send_message("/lora/rx", [str(name), rssi, snr, int(len(text)), str(text)])
            print(f"[rx] from={name} rssi={rssi} snr={snr} len={len(text)} text={text!r}")
    except Exception as e:
        print(f"[on_receive] erreur: {e}")


def on_connection(interface, topic=pub.AUTO_TOPIC):
    global my_num
    try:
        my_num = interface.myInfo.my_node_num
    except Exception:
        my_num = None
    print(f"[meshtastic] connecté (mon noeud = {my_num})")


def main():
    global osc
    ap = argparse.ArgumentParser()
    ap.add_argument("--tcp", metavar="IP", help="IP du T-Deck si connexion WiFi/TCP (sinon USB série)")
    ap.add_argument("--port", help="port série du T-Deck (auto-détecté si omis)")
    ap.add_argument("--host", default="127.0.0.1", help="IP du norns (127.0.0.1 si le pont tourne dessus)")
    ap.add_argument("--osc-port", type=int, default=10111)
    args = ap.parse_args()

    osc = SimpleUDPClient(args.host, args.osc_port)
    print(f"[lora_bridge] OSC -> {args.host}:{args.osc_port}")

    pub.subscribe(on_receive, "meshtastic.receive")
    pub.subscribe(on_connection, "meshtastic.connection.established")

    while True:
        try:
            if args.tcp:
                iface = meshtastic.tcp_interface.TCPInterface(hostname=args.tcp)
            else:
                iface = meshtastic.serial_interface.SerialInterface(devPath=args.port)
        except Exception as e:
            print(f"[lora_bridge] connexion impossible ({e}); nouvel essai dans 4 s")
            time.sleep(4)
            continue
        try:
            while True:
                time.sleep(1)                        # le pubsub tourne dans le thread de l'interface
        except KeyboardInterrupt:
            iface.close()
            return
        except Exception as e:
            print(f"[lora_bridge] perte de connexion ({e}); réouverture")
            try:
                iface.close()
            except Exception:
                pass
            time.sleep(3)


if __name__ == "__main__":
    main()
