#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Scanner de noeuds LoRa Meshtastic autour de toi.

Se connecte au T-Deck (par USB) et ecoute la radio pendant une duree donnee,
puis affiche tous les noeuds detectes sur LA MEME bande + LE MEME preset
(ex. EU_868 / LONG_FAST), tries par puissance de signal.

IMPORTANT : ne detecte que les appareils Meshtastic qui utilisent la meme
frequence ET le meme preset radio que ton T-Deck. Un appareil sur une autre
bande (ex. 433 MHz) ou un autre preset reste invisible (c'est physique).

Usage :
    py scan_lora_868.py                 # scan 60 s sur le 1er port detecte
    py scan_lora_868.py --port COM3     # force le port
    py scan_lora_868.py --secs 120      # scan plus long (plus de chances de capter)
"""

import argparse
import sys
import time

try:
    import meshtastic
    import meshtastic.serial_interface
    from meshtastic.protobuf import config_pb2
    from pubsub import pub
except ImportError:
    print("[!] Module 'meshtastic' manquant. Installe-le avec :")
    print("    py -m pip install meshtastic")
    sys.exit(1)

# node_id -> infos captees en direct (signal le plus frais)
live = {}


def fmt_age(ts):
    """Anciennete lisible : 12s / 5m / 2h."""
    if not ts:
        return "?"
    s = int(time.time() - ts)
    if s < 60:
        return f"{s}s"
    if s < 3600:
        return f"{s // 60}m"
    return f"{s // 3600}h"


def signal_bar(rssi):
    """Petite jauge visuelle a partir du RSSI (dBm)."""
    if rssi is None:
        return "      "
    if rssi >= -90:
        return "####  "   # tres proche / fort
    if rssi >= -110:
        return "###   "
    if rssi >= -125:
        return "##    "
    return "#     "       # tres faible / loin


def on_receive(packet, interface):
    """Appele a chaque paquet recu : on note le signal du voisin direct."""
    try:
        frm = packet.get("fromId") or hex(packet.get("from", 0))
        rssi = packet.get("rxRssi")
        snr = packet.get("rxSnr")
        hop_start = packet.get("hopStart")
        hop_limit = packet.get("hopLimit")
        # voisin DIRECT si aucun saut consomme (hopStart == hopLimit)
        direct = (
            hop_start is not None
            and hop_limit is not None
            and hop_start == hop_limit
        )
        rec = live.setdefault(frm, {})
        if rssi:
            rec["rssi"] = rssi
        if snr is not None:
            rec["snr"] = snr
        rec["direct"] = direct
        rec["last"] = time.time()
        # affichage en direct quand on capte un voisin a portee directe
        if direct and rssi:
            print(f"  > capte : {frm:<12} RSSI {rssi} dBm  SNR {snr} dB")
    except Exception:
        pass


def main():
    ap = argparse.ArgumentParser(description="Scanner de noeuds Meshtastic.")
    ap.add_argument("--port", default=None,
                    help="Port serie du T-Deck (ex. COM3). Auto si omis.")
    ap.add_argument("--secs", type=int, default=60,
                    help="Duree d'ecoute en secondes (defaut 60).")
    args = ap.parse_args()

    pub.subscribe(on_receive, "meshtastic.receive")

    print("Connexion au T-Deck...")
    try:
        iface = meshtastic.serial_interface.SerialInterface(devPath=args.port)
    except Exception as e:
        print(f"[!] Connexion impossible : {e}")
        print("    Verifie que le T-Deck est branche et qu'aucun autre logiciel")
        print("    (app Meshtastic, autre terminal) ne l'utilise.")
        sys.exit(1)

    # Sur quelle bande / preset on ecoute exactement
    try:
        lora = iface.localNode.localConfig.lora
        region = config_pb2.Config.LoRaConfig.RegionCode.Name(lora.region)
        preset = config_pb2.Config.LoRaConfig.ModemPreset.Name(lora.modem_preset)
        print(f"\nEcoute sur : region={region}  preset={preset}  slot={lora.channel_num}")
        print("(seuls les appareils sur CES memes reglages sont detectables)\n")
    except Exception:
        print()

    me = iface.myInfo.my_node_num if iface.myInfo else None

    print(f"Scan en cours pendant {args.secs} s... (Ctrl+C pour arreter avant)\n")
    try:
        time.sleep(args.secs)
    except KeyboardInterrupt:
        print("\nArret demande.")

    # --- Bilan final : on fusionne le carnet de noeuds + le signal capte en direct ---
    nodes = iface.nodes or {}
    rows = []
    for nid, n in nodes.items():
        user = n.get("user", {})
        if n.get("num") == me:
            continue  # on s'ignore soi-meme
        name = user.get("longName", "?")
        short = user.get("shortName", "?")
        hw = user.get("hwModel", "?")
        last = n.get("lastHeard")
        lv = live.get(nid, {})
        rssi = lv.get("rssi", n.get("snr") and None)  # priorite au live
        snr = lv.get("snr", n.get("snr"))
        direct = lv.get("direct", False)
        if lv.get("last"):
            last = lv["last"]
        rows.append({
            "name": name, "short": short, "hw": hw, "id": nid,
            "rssi": rssi, "snr": snr, "direct": direct, "last": last,
        })

    # tri : voisins directs et signal fort d'abord
    rows.sort(key=lambda r: (not r["direct"], -(r["rssi"] or -999)))

    print("\n" + "=" * 72)
    if not rows:
        print("Aucun autre noeud Meshtastic detecte sur cette bande/preset.")
        print("-> Soit personne a portee, soit ils sont sur une autre bande/preset.")
        print("   Astuce : relance avec --secs 180 pour ecouter plus longtemps.")
    else:
        print(f"{len(rows)} noeud(s) detecte(s) :\n")
        print(f"{'SIGNAL':<7}{'NOM':<20}{'COURT':<7}{'RSSI':>6} {'SNR':>5}  "
              f"{'DIRECT':<7}{'VU':>5}  MODELE")
        print("-" * 72)
        for r in rows:
            rssi = f"{r['rssi']}" if r["rssi"] is not None else "-"
            snr = f"{r['snr']:.1f}" if r["snr"] is not None else "-"
            direct = "oui" if r["direct"] else "(relais)"
            print(f"{signal_bar(r['rssi'])}{r['name'][:19]:<20}{r['short'][:6]:<7}"
                  f"{rssi:>6} {snr:>5}  {direct:<7}{fmt_age(r['last']):>5}  {r['hw']}")
        print("-" * 72)
        print("DIRECT=oui : capte en direct (voisin a portee radio).")
        print("DIRECT=(relais) : connu via un autre noeud (pas forcement a portee).")

    iface.close()
    print("\nTermine.")


if __name__ == "__main__":
    main()
