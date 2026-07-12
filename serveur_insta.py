# -*- coding: utf-8 -*-
"""
Serveur local de Capture Insta.
- Sert l'appli CaptureInsta.html
- POST /save : recoit la video, la convertit (ffmpeg) -> Videos\\CaptureInsta
- Filet de securite : surveille le dossier Telechargements et convertit
  automatiquement toute nouvelle capture-insta-*.mp4 / .webm
Aucune dependance externe (lib standard Python uniquement).
"""
import http.server, socketserver, os, subprocess, shutil, tempfile, datetime, json, threading, time, glob

PORT = 8777
ROOT = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
OUTDIR = os.path.join(HOME, "Videos", "CaptureInsta")
DOWNLOADS = os.path.join(HOME, "Downloads")
os.makedirs(OUTDIR, exist_ok=True)

def find_ffmpeg():
    p = shutil.which("ffmpeg")
    if p:
        return p
    guess = os.path.join(os.environ.get("LOCALAPPDATA", ""),
        r"Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe")
    return guess if os.path.exists(guess) else None

FFMPEG = find_ffmpeg()

def convert(src, out):
    """Convertit src -> out (MP4 H.264/AAC + faststart). Renvoie True si OK."""
    if not FFMPEG:
        return False
    r = subprocess.run([FFMPEG, "-y", "-i", src, "-c:v", "copy", "-c:a", "aac",
                        "-b:a", "192k", "-movflags", "+faststart", out], capture_output=True)
    if r.returncode != 0 or not os.path.exists(out):
        r = subprocess.run([FFMPEG, "-y", "-i", src, "-c:v", "libx264", "-preset",
                            "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a",
                            "aac", "-b:a", "192k", "-movflags", "+faststart", out],
                           capture_output=True)
    return r.returncode == 0 and os.path.exists(out)

def watch_downloads():
    """Convertit automatiquement toute nouvelle capture telechargee."""
    # On ignore les fichiers deja presents au demarrage
    seen = set(glob.glob(os.path.join(DOWNLOADS, "capture-insta-*")))
    sizes = {}
    while True:
        try:
            for f in glob.glob(os.path.join(DOWNLOADS, "capture-insta-*.mp4")) + \
                     glob.glob(os.path.join(DOWNLOADS, "capture-insta-*.webm")):
                if "_INSTA" in f or f in seen:
                    continue
                sz = os.path.getsize(f)
                # On attend que la taille soit stable (telechargement termine)
                if sizes.get(f) == sz and sz > 0:
                    ts = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                    out = os.path.join(OUTDIR, "insta_%s.mp4" % ts)
                    if convert(f, out):
                        print("  [auto] converti :", os.path.basename(f), "->", out)
                    seen.add(f)
                    sizes.pop(f, None)
                else:
                    sizes[f] = sz
        except Exception as e:
            pass
        time.sleep(2)

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path == "/ping":
            body = json.dumps({"ok": True, "ffmpeg": bool(FFMPEG)}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path != "/save":
            self.send_error(404); return
        length = int(self.headers.get("Content-Length", 0))
        ext = self.headers.get("X-Ext", "mp4")
        data = self.rfile.read(length)
        ts = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        tmp = os.path.join(tempfile.gettempdir(), "capture_%s.%s" % (ts, ext))
        with open(tmp, "wb") as f:
            f.write(data)
        out = os.path.join(OUTDIR, "insta_%s.mp4" % ts)
        ok = convert(tmp, out)
        try:
            os.remove(tmp)
        except OSError:
            pass
        body = json.dumps({"ok": ok, "path": out if ok else "", "ffmpeg": bool(FFMPEG)}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

if __name__ == "__main__":
    print("=" * 56)
    print("  CAPTURE INSTA - serveur")
    print("  -> http://localhost:%d/CaptureInsta.html" % PORT)
    print("  Videos pretes rangees dans :")
    print("  " + OUTDIR)
    print("  (Garder cette fenetre ouverte. Ctrl+C pour quitter.)")
    print("=" * 56)
    if not FFMPEG:
        print("  ATTENTION : ffmpeg introuvable -> conversion desactivee.")
    threading.Thread(target=watch_downloads, daemon=True).start()
    with Server(("127.0.0.1", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
