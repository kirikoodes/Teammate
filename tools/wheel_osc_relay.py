#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wheel_osc_relay.py — relais OSC entre la SmartKnob haptique (wheel.local) et le Norns (Teammate).

Pourquoi : la wheel streame son bundle (position/rpm/mode/force) vers le port 9001 du DERNIER
client qui lui a parle ; or le Norns n'ecoute l'OSC que sur 10111. Ce relais fait le pont, et
reste le "dernier client" de la wheel pour capter son flux.

  wheel:9001 (bundle 20 Hz) ── ce relais ──> norns:10111   (/wheel/position, /wheel/rpm)
  norns:9100 (commandes)     ── ce relais ──> wheel:9000    (/wheel/mode, /wheel/force, /wheel/rpm)

Lancer :  python3 wheel_osc_relay.py
Options : --wheel-host --norns-host --wheel-out-port(9001) --drive-port(9100)
"""
import argparse, threading, time
from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import ThreadingOSCUDPServer
from pythonosc.udp_client import SimpleUDPClient


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wheel-host", default="wheel.local")
    ap.add_argument("--wheel-port", type=int, default=9000)
    ap.add_argument("--wheel-out-port", type=int, default=9001, help="port ou la wheel nous streame")
    ap.add_argument("--norns-host", default="norns.local")
    ap.add_argument("--norns-port", type=int, default=10111)
    ap.add_argument("--drive-port", type=int, default=9100, help="port ou le Norns envoie ses commandes wheel")
    ap.add_argument("--keepalive", type=float, default=2.0, help="s entre deux poke (reste le dernier client)")
    args = ap.parse_args()

    # clients : on passe les hostnames -> sendto re-resout a chaque envoi (adapte au DHCP)
    _wheel = SimpleUDPClient(args.wheel_host, args.wheel_port)
    _norns = SimpleUDPClient(args.norns_host, args.norns_port)

    class Safe:
        def __init__(self, c): self.c = c
        def send_message(self, addr, val):
            try: self.c.send_message(addr, val)   # si l'hote n'est pas resolvable (eteint), on ignore
            except Exception: pass

    to_wheel = Safe(_wheel)
    to_norns = Safe(_norns)

    # etat courant (pour keepalive sans perturber le mode/rpm)
    state = {"force": 1.0}
    stat = {"in": 0, "out": 0}

    print("=== wheel_osc_relay ===", flush=True)
    print("  wheel      : %s:%d" % (args.wheel_host, args.wheel_port), flush=True)
    print("  wheel OUT  : ecoute %d" % args.wheel_out_port, flush=True)
    print("  norns      : %s:%d" % (args.norns_host, args.norns_port), flush=True)
    print("  drive IN   : ecoute %d (depuis le Norns)" % args.drive_port, flush=True)

    # --- wheel -> norns : recoit le bundle sur wheel-out-port, forward position + rpm ---
    fwd = Dispatcher()

    def on_pos(addr, *a):
        if a:
            to_norns.send_message("/wheel/position", float(a[0])); stat["in"] += 1

    def on_rpm(addr, *a):
        if a:
            to_norns.send_message("/wheel/rpm", float(a[0]))

    fwd.map("/wheel/position", on_pos)
    fwd.map("/wheel/rpm", on_rpm)
    fwd.set_default_handler(lambda addr, *a: None)   # ignore mode/force OUT

    # --- norns -> wheel : recoit les commandes sur drive-port, forward a la wheel ---
    drv = Dispatcher()

    def on_drive(addr, *a):
        if not a:
            return
        v = a[0]
        # force en float, mode en int, rpm en float
        if addr.endswith("/mode"):
            to_wheel.send_message(addr, int(v))
        elif addr.endswith("/force"):
            state["force"] = float(v); to_wheel.send_message(addr, float(v))
        else:
            to_wheel.send_message(addr, float(v))
        stat["out"] += 1

    drv.map("/wheel/*", on_drive)

    srv_wheel = ThreadingOSCUDPServer(("0.0.0.0", args.wheel_out_port), fwd)
    srv_drive = ThreadingOSCUDPServer(("0.0.0.0", args.drive_port), drv)
    threading.Thread(target=srv_wheel.serve_forever, daemon=True).start()
    threading.Thread(target=srv_drive.serve_forever, daemon=True).start()

    # reveil initial : donne un mode de depart (gros grain) + force normale
    to_wheel.send_message("/wheel/mode", 40)
    to_wheel.send_message("/wheel/force", 1.0)

    # keepalive : re-poke la force (n'altere ni le mode ni le rpm) pour rester le dernier client
    last = 0.0
    while True:
        to_wheel.send_message("/wheel/force", float(state["force"]))
        now = time.time()
        if now - last >= 5.0:
            print("[etat] wheel->norns %d msg | norns->wheel %d msg" % (stat["in"], stat["out"]), flush=True)
            last = now
        time.sleep(args.keepalive)


if __name__ == "__main__":
    main()
