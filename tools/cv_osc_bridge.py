#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cv_osc_bridge.py — Pont OSC <-> HAT modulaire CV/Gate (Raspberry Pi separe)
===========================================================================

Fait le lien entre TEAMMATE (sur le Norns) et un HAT Eurorack pour Raspberry Pi :
  - 8 sorties CV  : 2x DAC MCP4728  (I2C /dev/i2c-1, adresses 0x63 et 0x64)
  - 16 entrees CV : 2x ADC MCP3008  (SPI /dev/spidev0.0 et /dev/spidev0.1)

Sens du flux
------------
  TEAMMATE --OSC /cv/1..8 (float 0..1)-->  ce script  -->  8 CV OUT  --> ton modular
  ton modular --> 16 CV IN --> ce script --OSC /in/1..16 (float 0..1)--> TEAMMATE (SAMT)

Le cote ENTREE arrive tout seul dans SAMT/MONITOR de Teammate : n'importe quel OSC
numerique y est capte et auto-normalise. Rien a configurer cote Norns pour les /in.

Installation sur le Pi (Raspberry Pi OS)
----------------------------------------
  sudo raspi-config      # Interface Options -> activer SPI ET I2C, puis reboot
  sudo apt update && sudo apt install -y python3-pip python3-spidev
  pip3 install python-osc smbus2 spidev    # (spidev souvent deja la via apt)

Lancement
---------
  python3 cv_osc_bridge.py
  # options :
  #   --norns-host norns.local   (ou l'IP du Norns)   destination des /in
  #   --norns-port 10111         (port OSC d'ecoute de Teammate)
  #   --listen-port 9000         (port sur lequel CE Pi ecoute les /cv de Teammate)
  #   --rate 200                 (Hz de lecture/emission des 16 entrees)
  #   --no-hw                    (mode test SANS le HAT : parse l'OSC, pas d'I2C/SPI)

Cote Teammate : page OSC OUT, destination = <ip-de-ce-pi>:9000, adresses /cv/1..8.
"""

import argparse
import sys
import threading
import time

# ----- dependances OSC (obligatoire) --------------------------------------
try:
    from pythonosc.dispatcher import Dispatcher
    from pythonosc.osc_server import ThreadingOSCUDPServer
    from pythonosc.udp_client import SimpleUDPClient
except ImportError:
    sys.exit("Manque python-osc : pip3 install python-osc")

# ----- dependances materiel (optionnelles en mode --no-hw) ----------------
try:
    import spidev            # ADC MCP3008 (entrees)
    from smbus2 import SMBus, i2c_msg   # DAC MCP4728 (sorties)
    HW_LIBS = True
except ImportError:
    HW_LIBS = False

# ===== Constantes materielles (copiees du testeur C d'origine) ============
I2C_BUS       = 1               # /dev/i2c-1
DAC_ADDR      = (0x63, 0x64)    # les 2 MCP4728 -> canaux 0..3 chacun = 8 sorties
DAC_MAX       = 4095            # 12 bits
MCP4728_CMD   = 0x40            # (0x08<<3) : multi-write, UDAC=0 -> maj immediate
MCP4728_CFG_H = 0x80            # Vref interne (bit7=1), PD=0, gain x1 (bit4=0)

ADC_MAX       = 1023.0          # MCP3008 = 10 bits
ADC_CHANNELS  = 16              # 2x8 : ch 0..7 sur spidev0.0, 8..15 sur spidev0.1
SPI_SPEED_HZ  = 1_000_000


# ===== Sorties : 8 CV via les 2 MCP4728 (I2C) =============================
class DacOut:
    def __init__(self, no_hw=False):
        self.no_hw = no_hw or not HW_LIBS
        self.bus = None
        self.last = [-1] * 8
        if not self.no_hw:
            try:
                self.bus = SMBus(I2C_BUS)
            except PermissionError:
                print("[DAC] I2C refuse (permission). Lance avec 'sudo python3 cv_osc_bridge.py'")
                print("      ou ajoute ton user au groupe i2c : sudo usermod -aG i2c $USER puis reboot.")
                self.no_hw = True
            except Exception as e:
                print(f"[DAC] I2C indisponible ({e}) -> mode sans materiel")
                self.no_hw = True

    def selftest(self):
        """Rampe 0->10V sur les 8 sorties, puis retour a 0 : preuve visuelle que le materiel repond."""
        if self.no_hw or self.bus is None:
            print("[AUTO-TEST] saute (pas de materiel).")
            return
        print("[AUTO-TEST] rampe 0 -> 10V sur les 8 sorties (2s). REGARDE TES CV...")
        for step in range(0, 101):
            for i in range(8):
                self.set_cv(i, step / 100.0)
            time.sleep(0.02)
        for i in range(8):
            self.set_cv(i, 0.0)
        print("[AUTO-TEST] fini (sorties a 0). Si tes CV ont MONTE puis sont retombees -> le materiel MARCHE.")

    def set_cv(self, out_index, value01, force=False):
        """out_index 0..7, value01 float 0..1 -> tension CV sur la sortie. force = ecrit meme si identique (impulsions)."""
        if not (0 <= out_index < 8):
            return
        v = 0.0 if value01 < 0.0 else (1.0 if value01 > 1.0 else value01)
        raw = int(v * DAC_MAX + 0.5)
        if raw == self.last[out_index] and not force:
            return                     # rien a faire, evite le trafic I2C inutile
        self.last[out_index] = raw
        if self.no_hw or self.bus is None:
            return
        addr = DAC_ADDR[out_index // 4]
        channel = out_index % 4
        b0 = MCP4728_CMD | ((channel & 0x03) << 1)          # UDAC=0 : maj immediate
        b1 = MCP4728_CFG_H | ((raw >> 8) & 0x0F)
        b2 = raw & 0xFF
        try:
            self.bus.i2c_rdwr(i2c_msg.write(addr, [b0, b1, b2]))
        except Exception as e:
            print(f"[DAC] ecriture out{out_index+1} echouee : {e}")

    def close(self):
        if self.bus is not None:
            for i in range(8):         # remet les 8 sorties a 0 V a la fermeture
                self.set_cv(i, 0.0)
            self.bus.close()


# ===== Entrees : 16 CV via les 2 MCP3008 (SPI) ===========================
class AdcIn:
    def __init__(self, no_hw=False):
        self.no_hw = no_hw or not HW_LIBS
        self.spi = [None, None]
        if not self.no_hw:
            try:
                for i, (bus, dev) in enumerate(((0, 0), (0, 1))):
                    s = spidev.SpiDev()
                    s.open(bus, dev)
                    s.max_speed_hz = SPI_SPEED_HZ
                    s.mode = 0
                    self.spi[i] = s
            except Exception as e:
                print(f"[ADC] SPI indisponible ({e}) -> mode sans materiel")
                self.no_hw = True

    def read01(self, channel):
        """channel 0..15 -> float 0..1 (normalise). None si erreur."""
        if self.no_hw:
            return None
        spi = self.spi[0] if channel < 8 else self.spi[1]
        local = channel if channel < 8 else channel - 8
        if spi is None:
            return None
        try:
            r = spi.xfer2([1, (8 + local) << 4, 0])        # MCP3008 single-ended
        except Exception:
            return None
        raw = ((r[1] & 0x03) << 8) | r[2]
        return raw / ADC_MAX

    def close(self):
        for s in self.spi:
            if s is not None:
                s.close()


def main():
    ap = argparse.ArgumentParser(description="Pont OSC <-> HAT CV/Gate pour Teammate")
    ap.add_argument("--norns-host", default="norns.local", help="destination des /in (defaut norns.local)")
    ap.add_argument("--norns-port", type=int, default=10111, help="port OSC de Teammate (defaut 10111)")
    ap.add_argument("--listen-port", type=int, default=9000, help="port d'ecoute des /cv (defaut 9000)")
    ap.add_argument("--rate", type=float, default=200.0, help="Hz de lecture des 16 entrees (defaut 200)")
    ap.add_argument("--send-eps", type=float, default=0.004, help="seuil de changement pour re-emettre un /in")
    ap.add_argument("--no-hw", action="store_true", help="mode test sans le HAT (OSC seul)")
    ap.add_argument("--no-selftest", action="store_true", help="ne pas faire la rampe de test des sorties au demarrage")
    ap.add_argument("--trig-ms", type=float, default=5.0, help="largeur de l'impulsion /trig en millisecondes (defaut 5)")
    args = ap.parse_args()

    no_hw = args.no_hw or not HW_LIBS
    if no_hw and not args.no_hw:
        print("[!] Librairies materiel absentes (spidev/smbus2) -> mode --no-hw automatique.")

    dac = DacOut(no_hw=no_hw)
    adc = AdcIn(no_hw=no_hw)

    # --- OSC : reception des /cv/1..8 depuis Teammate ---------------------
    rx_stat = {"n": 0, "last": "-"}
    def on_cv(address, *osc_args):
        # address ex "/cv/3" ; 1 argument float 0..1
        try:
            idx = int(address.rsplit("/", 1)[1]) - 1     # /cv/1 -> index 0
        except (ValueError, IndexError):
            return
        if osc_args:
            val = float(osc_args[0])
            dac.set_cv(idx, val)
            rx_stat["n"] += 1
            rx_stat["last"] = f"{address}={val:.3f}"
            if rx_stat["n"] == 1:
                print(f"\n[RX] PREMIER paquet recu ! {rx_stat['last']}  <-- le signal arrive.")

    # --- OSC : /trig/N -> impulsion courte (Eurorack : 0V -> 10V pendant ~5 ms -> 0V) ---
    trig_s = max(0.0005, args.trig_ms / 1000.0)
    def on_trig(address, *osc_args):
        try:
            idx = int(address.rsplit("/", 1)[1]) - 1
        except (ValueError, IndexError):
            return
        level = float(osc_args[0]) if osc_args else 1.0   # 1.0 = 10V (plein), 0.5 = 5V
        dac.set_cv(idx, level, force=True)                # front montant immediat
        threading.Timer(trig_s, lambda: dac.set_cv(idx, 0.0, force=True)).start()   # retombee apres trig_ms
        rx_stat["n"] += 1 ; rx_stat["last"] = f"{address}(trig {args.trig_ms:.0f}ms)"
        if rx_stat["n"] == 1:
            print(f"\n[RX] PREMIER paquet recu ! {rx_stat['last']}  <-- le signal arrive.")

    # --- OSC : /gate/N v -> tient la tension (haut tant que v>0.5, sinon 0) ---
    def on_gate(address, *osc_args):
        try:
            idx = int(address.rsplit("/", 1)[1]) - 1
        except (ValueError, IndexError):
            return
        v = float(osc_args[0]) if osc_args else 0.0
        dac.set_cv(idx, v if v > 0.0 else 0.0, force=True)   # v=1.0 -> 10V maintenu ; 0 -> 0V
        rx_stat["n"] += 1 ; rx_stat["last"] = f"{address}={v:.1f}"

    disp = Dispatcher()
    disp.map("/cv/*", on_cv)                              # /cv/1 .. /cv/8  (CV continu)
    disp.map("/trig/*", on_trig)                          # /trig/1 .. /trig/8  (impulsion 5 ms)
    disp.map("/gate/*", on_gate)                          # /gate/1 .. /gate/8  (maintien)
    server = ThreadingOSCUDPServer(("0.0.0.0", args.listen_port), disp)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    # --- OSC : emission des /in/1..16 vers Teammate ----------------------
    client = SimpleUDPClient(args.norns_host, args.norns_port)

    print("=== Pont CV <-> OSC pour Teammate ===")
    print(f"  Ecoute /cv/1..8   sur 0.0.0.0:{args.listen_port}   (depuis Teammate)")
    print(f"  Envoie /in/1..16  vers {args.norns_host}:{args.norns_port}   ({args.rate:.0f} Hz)")
    print(f"  Materiel : {'NON (mode test)' if no_hw else 'MCP4728 x2 (DAC) + MCP3008 x2 (ADC)'}")
    print("  Ctrl+C pour quitter.\n")

    if not args.no_selftest:
        dac.selftest()          # preuve immediate que les sorties CV repondent (sans OSC)

    period = 1.0 / max(1.0, args.rate)
    last_sent = [None] * ADC_CHANNELS
    last_status = time.monotonic()
    prev_n = 0
    try:
        while True:
            t0 = time.monotonic()
            for ch in range(ADC_CHANNELS):
                v = adc.read01(ch)
                if v is None:
                    continue
                prev = last_sent[ch]
                if prev is None or abs(v - prev) >= args.send_eps:
                    last_sent[ch] = v
                    client.send_message(f"/in/{ch + 1}", v)   # -> SAMT : axe "/in/N#1"
            # ligne d'etat une fois par seconde : combien de /cv recus (= y a-t-il du signal ?)
            if t0 - last_status >= 1.0:
                rate = rx_stat["n"] - prev_n
                prev_n = rx_stat["n"]
                last_status = t0
                if rx_stat["n"] == 0:
                    print(f"[etat] AUCUN /cv recu (total 0). En attente de Teammate sur :{args.listen_port} ...")
                else:
                    print(f"[etat] /cv recus : {rx_stat['n']} total, {rate}/s | dernier {rx_stat['last']}")
            dt = period - (time.monotonic() - t0)
            if dt > 0:
                time.sleep(dt)
    except KeyboardInterrupt:
        print("\nArret...")
    finally:
        server.shutdown()
        dac.close()
        adc.close()
        print("Sorties remises a 0 V. Bye.")


if __name__ == "__main__":
    main()
