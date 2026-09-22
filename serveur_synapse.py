# -*- coding: utf-8 -*-
"""
SYNAPSE - serveur local.
- Sert l'appli Synapse.html
- /api/plan    : decoupe un prompt (FR/EN) en couches sonores + requetes de recherche
                 (Claude si dispo, sinon analyseur local FR->EN)
- /api/search  : cherche des field recordings libres (Freesound direct si cle, sinon via Openverse ; + Wikimedia Commons)
- /api/audio   : proxy audio (CORS) pour que le navigateur puisse mixer / enregistrer
- /api/images  : photos libres liees a une requete (Openverse CC0/PD/BY/BY-SA + Wikimedia Commons)
- /api/media   : proxy des images / videos renvoyees par /api/images et /api/videos (cache disque, Range)
- /api/videos  : clips video libres lies a une requete (Wikimedia Commons, versions 480p)
- /api/bank    : banque de scenes (couches + sons choisis + reglages), un JSON par scene dans banque/
- /api/config  : lit / enregistre les cles locales (synapse_config.json, jamais commite)
Lib standard Python uniquement ; le SDK `anthropic` est optionnel (pip install anthropic).
"""
import http.server, socketserver, os, json, re, unicodedata, urllib.request, urllib.error, urllib.parse, threading,     hashlib, time

PORT = int(__import__("sys").argv[1]) if len(__import__("sys").argv) > 1 else 8778  # port optionnel en argument
ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(ROOT, "synapse_config.json")
# Wikimedia exige un User-Agent avec un contact (URL ou mail), sinon 429 systematique
UA = "SynapseAmbient/0.1 (https://github.com/kirikoodes/Teammate; personal sound-art instrument) python-urllib"
MAX_AUDIO_BYTES = 25 * 1024 * 1024
MAX_COMMONS_BYTES = 9 * 1024 * 1024  # evite les enregistrements geants (lents + rate-limit)
AUDIO_HOSTS = ("upload.wikimedia.org", "cdn.freesound.org", "freesound.org")

CACHE_DIR = os.path.join(ROOT, "synapse_cache")
_cfg_lock = threading.Lock()
_dl_lock = threading.Lock()  # Wikimedia renvoie 429 si on telecharge en rafale : 1 a la fois, espaces
_dl_last = [0.0]
MIN_GAP = 1.2
_no_lock = __import__("contextlib").nullcontext()


def load_config():
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_config(cfg):
    with _cfg_lock:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)


def freesound_key():
    return os.environ.get("FREESOUND_API_KEY") or load_config().get("freesound_key", "")


def anthropic_key():
    return os.environ.get("ANTHROPIC_API_KEY") or load_config().get("anthropic_key", "")


def http_json(url, timeout=12):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


# ------------------------------------------------------------------ PLANNER (local)

def strip_accents(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


# expressions multi-mots d'abord (cle sans accents)
PHRASES = {
    "combats medievaux": "sword fight", "combat medieval": "sword fight", "bataille medievale": "medieval battle",
    "combat d'epee": "sword fight", "combats d'epee": "sword fight", "combat a l'epee": "sword fight",
    "feu de camp": "campfire", "feu de bois": "fireplace crackling", "chant d'oiseaux": "birdsong",
    "chants d'oiseaux": "birdsong", "bord de mer": "seaside waves", "coup de tonnerre": "thunder",
    "coups de feu": "gunshots", "coup de feu": "gunshot", "salle de classe": "classroom",
    "gare routiere": "bus station", "station de metro": "subway station", "pas dans la neige": "footsteps snow",
    "bruit de pas": "footsteps", "bruits de pas": "footsteps", "cour de recreation": "playground children",
    "machine a ecrire": "typewriter", "machine a laver": "washing machine", "centre commercial": "shopping mall",
    "salle des machines": "engine room", "vent fort": "strong wind", "pluie fine": "light rain",
    "grosse pluie": "heavy rain", "foret tropicale": "rainforest", "fete foraine": "funfair",
    "marche de noel": "christmas market", "chantier naval": "shipyard", "vaisseau spatial": "spaceship hum",
    "radio grésillante": "radio static", "radio gresillante": "radio static", "sous l'eau": "underwater",
}

WORDS = {
    # animaux
    "chien": "dog", "chiens": "dogs", "chat": "cat", "chats": "cats", "oiseau": "bird", "oiseaux": "birds",
    "corbeau": "crow", "corbeaux": "crows", "mouette": "seagull", "mouettes": "seagulls", "cheval": "horse",
    "chevaux": "horses", "vache": "cow", "vaches": "cows", "mouton": "sheep", "moutons": "sheep",
    "loup": "wolf", "loups": "wolves", "grenouille": "frog", "grenouilles": "frogs", "insecte": "insects",
    "insectes": "insects", "grillon": "crickets", "grillons": "crickets", "cigale": "cicadas", "cigales": "cicadas",
    "abeille": "bees", "abeilles": "bees", "mouche": "fly buzz", "mouches": "flies", "coq": "rooster",
    "poule": "chicken", "poules": "chickens", "canard": "duck", "canards": "ducks", "baleine": "whale",
    "baleines": "whales", "dauphin": "dolphin", "hibou": "owl", "chouette": "owl", "singe": "monkey",
    "singes": "monkeys", "lion": "lion", "elephant": "elephant", "cochon": "pig", "cochons": "pigs",
    "aboiement": "dog bark", "aboiements": "dog barking", "miaulement": "cat meow",
    # lieux
    "supermarche": "supermarket", "magasin": "shop", "marche": "market", "gare": "train station",
    "aeroport": "airport", "metro": "subway", "rue": "street", "ville": "city", "foret": "forest",
    "bois": "woods", "plage": "beach", "mer": "sea", "ocean": "ocean", "riviere": "river", "ruisseau": "stream",
    "cascade": "waterfall", "lac": "lake", "montagne": "mountain", "desert": "desert", "grotte": "cave",
    "cave": "cellar", "eglise": "church", "cathedrale": "cathedral", "ecole": "school", "hopital": "hospital",
    "usine": "factory", "chantier": "construction site", "cuisine": "kitchen", "restaurant": "restaurant",
    "cafe": "cafe", "bar": "bar", "bureau": "office", "parking": "parking garage", "port": "harbor",
    "ferme": "farm", "jardin": "garden", "parc": "park", "piscine": "swimming pool", "stade": "stadium",
    "bibliotheque": "library", "tunnel": "tunnel", "pont": "bridge", "village": "village", "jungle": "jungle",
    "campagne": "countryside", "prairie": "meadow", "marais": "swamp", "chateau": "castle", "prison": "prison",
    "laboratoire": "laboratory", "hangar": "hangar", "entrepot": "warehouse", "autoroute": "highway",
    # meteo / elements
    "pluie": "rain", "orage": "thunderstorm", "tonnerre": "thunder", "vent": "wind", "tempete": "storm",
    "neige": "snow", "grele": "hail", "vagues": "waves", "vague": "waves", "feu": "fire", "eau": "water",
    "glace": "ice", "gouttes": "dripping water", "goutte": "water drip",
    # humains
    "foule": "crowd", "gens": "people talking", "enfants": "children playing", "enfant": "child",
    "bebe": "baby", "voix": "voices", "conversation": "conversation", "rires": "laughter", "rire": "laughter",
    "cris": "screams", "cri": "scream", "applaudissements": "applause", "pas": "footsteps",
    "murmures": "whispers", "chuchotements": "whispers", "chorale": "choir", "choeur": "choir",
    "priere": "prayer", "moines": "monks chanting", "soldats": "soldiers marching", "armee": "army",
    "chevaliers": "knights armor", "chevalier": "knight armor",
    # actions / evenements
    "combat": "fight", "combats": "fighting", "bataille": "battle", "guerre": "war", "explosion": "explosion",
    "explosions": "explosions", "epee": "sword", "epees": "swords clash", "armure": "armor", "fleches": "arrows",
    "fusillade": "gunfire", "course": "running", "danse": "dance", "fete": "party", "manifestation": "protest",
    # machines / objets
    "voiture": "car", "voitures": "cars traffic", "circulation": "traffic", "train": "train", "trains": "trains",
    "avion": "airplane", "avions": "airplanes", "helicoptere": "helicopter", "bateau": "boat", "bateaux": "boats",
    "moto": "motorcycle", "velo": "bicycle", "bus": "bus", "camion": "truck", "sirene": "siren",
    "sirenes": "sirens", "cloche": "bell", "cloches": "church bells", "horloge": "clock ticking",
    "telephone": "phone ringing", "radio": "radio", "television": "tv", "ordinateur": "computer",
    "machine": "machine", "machines": "machinery", "moteur": "engine", "robot": "robot", "porte": "door",
    "portes": "doors", "caisse": "cash register", "caisses": "cash registers", "chariot": "shopping cart",
    "chariots": "shopping carts", "ventilateur": "fan", "frigo": "fridge hum", "refrigerateur": "fridge hum",
    "climatisation": "air conditioning", "ascenseur": "elevator", "escalator": "escalator",
    "annonce": "announcement", "annonces": "public announcement", "musique": "music", "piano": "piano",
    "guitare": "guitar", "tambour": "drum", "tambours": "drums", "violon": "violin", "orgue": "organ",
    "vaisseau": "spaceship", "alarme": "alarm", "bip": "beep", "bips": "beeps",
    # qualites
    "medieval": "medieval", "medievale": "medieval", "medievaux": "medieval", "medievales": "medieval",
    "lointain": "distant", "lointaine": "distant", "lointains": "distant", "proche": "close",
    "nocturne": "night", "nuit": "night", "matin": "morning", "soir": "evening", "grand": "big",
    "grande": "big", "petit": "small", "petite": "small", "fort": "loud", "forte": "heavy",
    "doux": "soft", "douce": "soft", "calme": "calm", "vide": "empty", "abandonne": "abandoned",
    "abandonnee": "abandoned", "futuriste": "futuristic", "industriel": "industrial", "electrique": "electric",
    "metallique": "metallic", "souterrain": "underground", "tropical": "tropical", "urbain": "urban",
    "bonde": "busy", "bondee": "busy", "anime": "busy", "animee": "busy", "silencieux": "quiet",
}

STOP = set(("un une des le la les du de d l au aux en a et ou avec dans sur sous pendant puis ainsi que qui "
            "quelque quelques plein plusieurs beaucoup tres trop un peu genre euh bah ben alors voila "
            "comme par pour chez vers entre il y ya on je tu nous vous ils elles c ce cette ces son sa ses "
            "leur leurs mon ma mes est sont etre fait faire the of and with in on at a an some").split())

SPLIT_RE = re.compile(r"\s*(?:,|;|\+|\bavec\b|\bdans\b|\bet\b|\bpuis\b|\bpendant\b|\bsous\b|\bsur\b|"
                      r"\bpres d[eu]\b|\bau milieu d[eu]?\b|\bwith\b|\bin\b|\band\b|\bover\b|\bunder\b)\s*")

ROLE_HINT = {  # role d'une couche : fond (bed), texture, evenement
    "bed": ("supermarket", "forest", "city", "street", "rain", "wind", "sea", "ocean", "river", "crowd", "traffic",
            "factory", "airport", "train station", "subway", "beach", "jungle", "countryside", "cave", "church",
            "office", "restaurant", "cafe", "market", "desert", "storm", "night", "underwater", "room", "hum",
            "shopping mall", "warehouse", "laboratory", "highway", "harbor", "farm", "park", "swamp", "meadow"),
    "event": ("dog", "bark", "explosion", "gunshot", "door", "bell", "scream", "thunder", "siren", "phone",
              "horse", "rooster", "alarm", "beep", "cash register", "announcement", "sword", "fight", "battle"),
}


def guess_role(q):
    for role, keys in ROLE_HINT.items():
        if any(re.search(r"\b" + re.escape(k) + r"s?\b", q) for k in keys):
            return role
    return "texture"


def clean_label(chunk):
    words = [w for w in chunk.split() if w.split("'")[-1] not in STOP or len(chunk.split()) == 1]
    return " ".join(words) or chunk


def local_plan(prompt):
    raw = prompt.strip()
    low = strip_accents(raw.lower()).replace("’", "'")
    chunks = [c for c in SPLIT_RE.split(low) if c and c.strip()]
    layers = []
    for chunk in chunks:
        c = " " + chunk.strip() + " "
        found = []
        for fr, en in sorted(PHRASES.items(), key=lambda kv: -len(kv[0])):
            k = " " + fr + " "
            if k in c:
                found.append(en)
                c = c.replace(k, " ")
        words = [w for w in re.split(r"[^a-z0-9']+", c) if w]
        words = [w.split("'")[-1] for w in words]
        words = [w for w in words if w and w not in STOP]
        tr = [WORDS.get(w, WORDS.get(w.rstrip("s"), None)) for w in words]
        # nom d'abord (les adjectifs FR sont apres le nom -> on les met devant en EN)
        nouns = [t for w, t in zip(words, tr) if t and not is_adj(w)]
        adjs = [t for w, t in zip(words, tr) if t and is_adj(w)]
        unknown = [w for w, t in zip(words, tr) if not t and len(w) > 2]
        main = found + nouns
        if not main and not unknown:
            continue
        head = (main[0] if main else unknown[0])
        q1 = " ".join(adjs + [head]).strip()
        queries = [q1]
        if len(main) > 1:
            queries.append(" ".join(main[:2]))
        if head != q1:
            queries.append(head)
        if unknown:
            queries.append(" ".join(unknown[:2]))  # on tente aussi le mot brut (titres FR sur Commons)
        if guess_role(" ".join(queries)) == "bed":
            queries.insert(0, q1 + " ambience")
        queries = list(dict.fromkeys(q for q in queries if q))
        layers.append({
            "label": clean_label(chunk.strip()),
            "queries": queries[:4],
            "role": guess_role(" ".join(queries)),
        })
    if not layers:
        layers.append({"label": raw, "queries": [raw], "role": "texture"})
    for L in layers:
        L["gain"] = {"bed": 0.8, "texture": 0.6, "event": 0.5}[L["role"]]
        L["pan"] = 0.0
    spread_pan(layers)
    return {"engine": "local", "layers": layers[:8]}


ADJ = set(k for k, v in WORDS.items() if v in (
    "medieval", "distant", "close", "night", "morning", "evening", "big", "small", "loud", "heavy", "soft",
    "calm", "empty", "abandoned", "futuristic", "industrial", "electric", "metallic", "underground",
    "tropical", "urban", "busy", "quiet"))


def is_adj(w):
    return w in ADJ


def spread_pan(layers):
    n = len(layers)
    for i, L in enumerate(layers):
        if L["role"] == "bed":
            L["pan"] = 0.0
        else:
            L["pan"] = round(((i + 0.5) / n) * 1.6 - 0.8, 2)


# ------------------------------------------------------------------ PLANNER (Claude)

PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "layers": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "label": {"type": "string"},
                    "role": {"type": "string", "enum": ["bed", "texture", "event"]},
                    "queries": {"type": "array", "items": {"type": "string"}},
                    "gain": {"type": "number"},
                    "pan": {"type": "number"},
                },
                "required": ["label", "role", "queries", "gain", "pan"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["layers"],
    "additionalProperties": False,
}

PLAN_SYSTEM = (
    "You are the sound-design brain of an ambient instrument. The user describes a scene, often in spoken "
    "French with hesitations. Decompose it into 2 to 7 simultaneous sound layers that a field-recording "
    "library could supply. For each layer give: a short French label; a role (bed = continuous background "
    "ambience, texture = recurring mid-ground sounds, event = sporadic foreground sounds); 3 short English "
    "search queries ordered from most specific to most generic, phrased the way sounds are tagged on "
    "Freesound or Wikimedia Commons (e.g. 'supermarket ambience', 'dog barking indoor', 'sword clash'); a gain "
    "between 0.2 and 1.0 (beds louder, events quieter); and a stereo pan between -1 and 1. Add implied layers "
    "only when they clearly serve the scene (e.g. a room tone for an indoor place). Ignore filler words.")


def claude_plan(prompt):
    key = anthropic_key()
    try:
        import anthropic
    except ImportError:
        return None
    try:
        client = anthropic.Anthropic(api_key=key) if key else anthropic.Anthropic()
    except Exception:
        return None
    base = dict(
        model="claude-opus-5",
        max_tokens=4000,
        system=PLAN_SYSTEM,
        output_config={"effort": "low",
                       "format": {"type": "json_schema", "schema": PLAN_SCHEMA}},
        messages=[{"role": "user", "content": prompt}],
    )
    try:
        try:
            # repli serveur si le modele decline la requete
            resp = client.beta.messages.create(
                betas=["server-side-fallback-2026-07-01"], fallbacks="default", **base)
        except anthropic.BadRequestError:
            resp = client.messages.create(**base)
    except (anthropic.AuthenticationError, anthropic.PermissionDeniedError):
        return None
    except anthropic.APIError as e:
        print("[claude] erreur:", e)
        return None
    if resp.stop_reason == "refusal":
        return None
    text = next((b.text for b in resp.content if b.type == "text"), "")
    try:
        data = json.loads(text)
    except ValueError:
        return None
    layers = data.get("layers") or []
    for L in layers:
        L["queries"] = [q for q in L.get("queries", []) if q][:4] or [L.get("label", prompt)]
        L["gain"] = max(0.1, min(1.0, float(L.get("gain", 0.6))))
        L["pan"] = max(-1.0, min(1.0, float(L.get("pan", 0))))
    return {"engine": "claude", "layers": layers[:8]} if layers else None


def plan(prompt):
    return claude_plan(prompt) or local_plan(prompt)


# ------------------------------------------------------------------ SEARCH

# fichiers de prononciation, morceaux d'album, articles lus : pas des field recordings
NOISE_TITLE = re.compile(r"^File:(LL-Q\d|[A-Za-z]{2,3}(-[A-Za-z]{2,4})?-|.*\s-\s\d{1,2}\s-\s|.*(article|spoken|pronunciation|librivox|audiobook|chapter))",
                         re.I)


def search_commons(q, limit=20):
    params = {
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": q + " filetype:audio", "gsrnamespace": "6", "gsrlimit": str(limit),
        "prop": "imageinfo", "iiprop": "url|mime|size|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|Artist",
    }
    data = http_json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params))
    terms = [t for t in q.lower().split() if len(t) > 2]
    pages = sorted((data.get("query") or {}).get("pages", {}).values(),
                   key=lambda p: (-sum(t in p.get("title", "").lower() for t in terms), p.get("index", 99)))
    out = []
    for p in pages:
        ii = (p.get("imageinfo") or [{}])[0]
        mime = ii.get("mime", "")
        if not (mime.startswith("audio/") or mime == "application/ogg"):
            continue
        if ii.get("size", 0) > MAX_COMMONS_BYTES or "midi" in mime:
            continue
        if NOISE_TITLE.search(p.get("title", "")):
            continue
        dur = ii.get("duration") or 0
        if dur and dur < 1.0:
            continue
        meta = ii.get("extmetadata") or {}
        artist = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "")).strip()
        out.append({
            "source": "commons",
            "title": p.get("title", "").replace("File:", "").rsplit(".", 1)[0],
            "url": ii.get("url", "").split("?")[0],
            "page": ii.get("descriptionurl", ""),
            "duration": round(dur, 1),
            "license": (meta.get("LicenseShortName") or {}).get("value", "?"),
            "author": artist[:60],
        })
    return out


def search_freesound(q, limit=12):
    key = freesound_key()
    if not key:
        return []
    params = {
        "query": q, "token": key, "page_size": str(limit),
        "fields": "id,name,previews,duration,license,username,url",
        "filter": "duration:[2 TO 600]", "sort": "score",
    }
    data = http_json("https://freesound.org/apiv2/search/text/?" + urllib.parse.urlencode(params))
    out = []
    for r in data.get("results", []):
        pv = r.get("previews") or {}
        url = pv.get("preview-hq-mp3") or pv.get("preview-lq-mp3")
        if not url:
            continue
        lic = r.get("license", "")
        lic = ("CC0" if "zero" in lic else "CC BY-NC" if "nc" in lic.lower() else
               "CC BY" if "/by/" in lic else "CC")
        out.append({
            "source": "freesound", "title": r.get("name", ""), "url": url, "page": r.get("url", ""),
            "duration": round(r.get("duration", 0), 1), "license": lic, "author": r.get("username", ""),
        })
    return out


_ov_cache = {}


def search_openverse(q, limit=15):
    """Freesound SANS cle, via l'index Openverse (api.openverse.org, anonyme)."""
    if freesound_key():
        return []  # l'API Freesound directe prend le relais
    if q in _ov_cache:
        return _ov_cache[q]
    params = {"q": q, "source": "freesound", "page_size": str(limit)}
    data = http_json("https://api.openverse.org/v1/audio/?" + urllib.parse.urlencode(params))
    out = []
    for r in data.get("results", []):
        url = r.get("url") or ""
        dur = (r.get("duration") or 0) / 1000.0
        if not url or (dur and not 2 <= dur <= 600):
            continue
        lic = (r.get("license") or "").upper()
        lic = "CC0" if lic == "CC0" else "CC " + lic.replace("-", " ").replace("BY NC", "BY-NC").replace("BY SA", "BY-SA")
        if r.get("license_version") and lic != "CC0":
            lic += " " + r["license_version"]
        out.append({
            "source": "freesound", "via": "openverse", "title": r.get("title", ""), "url": url,
            "page": r.get("foreign_landing_url", ""), "duration": round(dur, 1), "license": lic,
            "author": r.get("creator", ""),
        })
    _ov_cache[q] = out
    return out


def search(q):
    results, errors = [], []
    for fn in (search_freesound, search_openverse, search_commons):
        try:
            results.append(fn(q))
        except Exception as e:
            errors.append(f"{fn.__name__}: {e}")
            results.append([])
    # entrelace les sources pour varier
    merged = []
    for i in range(max((len(r) for r in results), default=0)):
        for r in results:
            if i < len(r):
                merged.append(r[i])
    return {"query": q, "results": merged, "errors": errors}


# ------------------------------------------------------------------ IMAGES

_issued = set()          # URLs d'images renvoyees par /api/images : seules celles-ci passent par le proxy
_img_cache = {}
MAX_IMAGE_BYTES = 12 * 1024 * 1024
# pas de cartes, schemas, logos, affiches, captures... : on veut des photos "propres", sans texte incruste
IMG_NOISE = re.compile(r"\b(map|carte|diagram|chart|graph|logo|icon|poster|affiche|flyer|stamp|coat of arms|"
                       r"blason|flag|drapeau|screenshot|infographic|text|typography|sign|label|plan|svg|"
                       r"illustration|drawing|clipart|vector|cartoon|meme|quote|banner)\b", re.I)


# JAMAIS d'images d'enfants : tout titre / tag / categorie / description qui evoque un enfant
# (ou un contexte ou il y en a souvent) exclut l'image. Plusieurs langues. Filtre volontairement large.
CHILD = re.compile(r"\b(child|children|childhood|childs?|kids?|kiddos?|boys?|girls?|bab(y|ies)|infants?|toddlers?|newborns?|"
                   r"teens?|teenagers?|adolescents?|youths?|juniors?|juveniles?|minors?|pupils?|students?|schools?|"
                   r"schoolchildren|schoolboys?|schoolgirls?|school ?kids?|kindergartens?|preschools?|daycares?|nursery|"
                   r"nurseries|playgrounds?|toys?|dolls?|scouts?|cub scouts?|brownies|sons?|daughters?|grandchild(ren)?|"
                   r"grandsons?|granddaughters?|famil(y|ies)|mother|father|parents?|moms?|dads?|maternity|christening|"
                   r"baptism|first communion|birthday party|orphans?|orphanage|"
                   r"enfants?|enfance|b[eé]b[eé]s?|gar[cç]ons?|filles?|fillettes?|gamins?|gamines?|gosses?|mômes?|momes?|"
                   r"ados?|adolescents?|jeunes?|[eé]l[eè]ves?|[eé]coles?|coll[eè]ges?|maternelles?|cr[eè]ches?|"
                   r"ni[nñ]os?|ni[nñ]as?|chicos?|chicas?|kinder|kindern?|m[aä]dchen|jungen?|bambin[oi]|bambin[ae]|ragazz[oiae]|"
                   r"crian[cç]as?|meninos?|meninas?|dzieci|дети|ребен(ок|ка))\b", re.I)


def _no_child(*texts):
    return not any(CHILD.search(t or "") for t in texts)


def _img_ok(title, w, h):
    if IMG_NOISE.search(title or "") or not _no_child(title):
        return False
    if not w or not h or w < 900:
        return False
    return 0.6 <= w / h <= 2.4


def search_images_openverse(q, page=1, limit=20):  # 20 = maximum en anonyme (sinon 401)
    params = {"q": q, "page": str(page), "license": "cc0,pdm,by,by-sa", "category": "photograph", "size": "large",
              "page_size": str(limit), "mature": "false"}
    data = http_json("https://api.openverse.org/v1/images/?" + urllib.parse.urlencode(params))
    out = []
    for r in data.get("results", []):
        if not _img_ok(r.get("title"), r.get("width"), r.get("height")):
            continue
        tags = " ".join(t.get("name", "") for t in (r.get("tags") or []) if isinstance(t, dict))
        if not _no_child(tags, r.get("description"), r.get("foreign_landing_url"), r.get("url")):
            continue
        lic = (r.get("license") or "").upper()
        lic = lic if lic in ("CC0", "PDM") else "CC " + lic.replace("BY-SA", "BY-SA") + (" " + r["license_version"] if r.get("license_version") else "")
        out.append({"source": "openverse/" + (r.get("source") or "?"), "title": r.get("title", ""), "url": r.get("url", ""),
                    "page": r.get("foreign_landing_url", ""), "license": lic, "author": r.get("creator", ""),
                    "w": r.get("width"), "h": r.get("height")})
    return out


def search_images_commons(q, page=1, limit=20):
    params = {
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": q + " filetype:bitmap", "gsrnamespace": "6", "gsrlimit": str(limit), "gsroffset": str((page - 1) * limit),
        "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": "1280",
        "iiextmetadatafilter": "LicenseShortName|Artist|Categories|ImageDescription|ObjectName",
    }
    data = http_json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params))
    out = []
    for p in sorted((data.get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99)):
        ii = (p.get("imageinfo") or [{}])[0]
        title = p.get("title", "").replace("File:", "").rsplit(".", 1)[0]
        em = ii.get("extmetadata") or {}
        if not _no_child(*[re.sub(r"<[^>]+>", " ", str((em.get(k) or {}).get("value", ""))) for k in ("Categories", "ImageDescription", "ObjectName")]):
            continue
        if ii.get("mime") not in ("image/jpeg", "image/png", "image/webp") or not _img_ok(title, ii.get("width"), ii.get("height")):
            continue
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "?")
        if "NC" in lic.upper() or "ND" in lic.upper() or "fair use" in lic.lower():
            continue
        out.append({"source": "commons", "title": title, "url": ii.get("thumburl") or ii.get("url", ""),
                    "page": ii.get("descriptionurl", ""), "license": lic,
                    "author": re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "")).strip()[:60],
                    "w": ii.get("width"), "h": ii.get("height")})
    return out


def search_images(q, page=1):
    if not _no_child(q):
        return {"query": q, "page": page, "results": [], "errors": [], "filtered": "enfants"}
    key = (q, page)
    if key in _img_cache:
        return _img_cache[key]
    results, errors = [], []
    for fn in (search_images_openverse, search_images_commons):
        try:
            results.append(fn(q, page))
        except Exception as e:
            errors.append(f"{fn.__name__}: {e}")
            results.append([])
    merged, seen = [], set()
    for i in range(max((len(r) for r in results), default=0)):
        for r in results:
            if i < len(r) and r[i]["url"] and r[i]["url"] not in seen:
                seen.add(r[i]["url"])
                merged.append(r[i])
    for m in merged:
        _issued.add(m["url"])
    out = {"query": q, "page": page, "results": merged, "errors": errors}
    if merged or not errors:
        _img_cache[key] = out
    return out


# ------------------------------------------------------------------ VIDEOS

MAX_VIDEO_BYTES = 40 * 1024 * 1024
_vid_cache = {}


def search_videos(q, page=1, limit=20):
    """Clips libres de Wikimedia Commons (transcodes 480p webm/vp9), memes filtres que les images."""
    if not _no_child(q):
        return {"query": q, "page": page, "results": [], "errors": [], "filtered": "enfants"}
    key = (q, page)
    if key in _vid_cache:
        return _vid_cache[key]
    params = {
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": q + " filetype:video", "gsrnamespace": "6", "gsrlimit": str(limit), "gsroffset": str((page - 1) * limit),
        "prop": "videoinfo", "viprop": "url|size|mime|derivatives|extmetadata",
        "viextmetadatafilter": "LicenseShortName|Artist|Categories|ImageDescription|ObjectName",
    }
    out, errors = [], []
    try:
        data = http_json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params))
        for p in sorted((data.get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99)):
            vi = (p.get("videoinfo") or [{}])[0]
            title = p.get("title", "").replace("File:", "").rsplit(".", 1)[0]
            em = vi.get("extmetadata") or {}
            dur = float(vi.get("duration") or 0)
            if IMG_NOISE.search(title) or not _no_child(title, *[re.sub(r"<[^>]+>", " ", str((em.get(k) or {}).get("value", "")))
                                                                  for k in ("Categories", "ImageDescription", "ObjectName")]):
                continue
            if not 3 <= dur <= 900 or (vi.get("width") or 0) < 320:
                continue
            lic = (em.get("LicenseShortName") or {}).get("value", "?")
            if "NC" in lic.upper() or "ND" in lic.upper():
                continue
            ders = {d.get("transcodekey"): d.get("src") for d in (vi.get("derivatives") or []) if d.get("transcodekey")}
            src = ders.get("480p.vp9.webm") or ders.get("360p.vp9.webm") or ders.get("720p.vp9.webm") or ders.get("360p.webm") or ders.get("480p.webm")
            if not src:
                continue
            out.append({"type": "video", "source": "commons", "title": title, "url": src, "page": vi.get("descriptionurl", ""),
                        "license": lic, "author": re.sub(r"<[^>]+>", "", (em.get("Artist") or {}).get("value", "")).strip()[:60],
                        "w": vi.get("width"), "h": vi.get("height"), "duration": round(dur, 1)})
    except Exception as e:
        errors.append(f"search_videos: {e}")
    for m in out:
        _issued.add(m["url"])
    res = {"query": q, "page": page, "results": out, "errors": errors}
    if not errors:
        _vid_cache[key] = res
    return res


# ------------------------------------------------------------------ BANQUE DE SCENES

BANK_DIR = os.path.join(ROOT, "banque")
BANK_ID = re.compile(r"^[0-9]{8}-[0-9]{6}-[a-z0-9-]{0,40}$")


def bank_list():
    os.makedirs(BANK_DIR, exist_ok=True)
    out = []
    for f in sorted(os.listdir(BANK_DIR), reverse=True):
        if not f.endswith(".json"):
            continue
        try:
            with open(os.path.join(BANK_DIR, f), encoding="utf-8") as fh:
                sc = json.load(fh)
            out.append({"id": f[:-5], "name": sc.get("name", f[:-5]), "date": sc.get("date", ""),
                        "layers": [L.get("label", "") for L in sc.get("layers", [])],
                        "prompts": sc.get("prompts", [])[:3]})
        except (OSError, ValueError):
            continue
    return out


def bank_save(scene):
    os.makedirs(BANK_DIR, exist_ok=True)
    name = str(scene.get("name") or "scene")[:80]
    slug = re.sub(r"[^a-z0-9]+", "-", strip_accents(name.lower())).strip("-")[:40]
    sid = time.strftime("%Y%m%d-%H%M%S") + "-" + slug
    with open(os.path.join(BANK_DIR, sid + ".json"), "w", encoding="utf-8") as f:
        json.dump(scene, f, ensure_ascii=False, indent=1)
    return sid


def bank_path(sid):
    if not BANK_ID.match(sid or ""):
        return None
    path = os.path.join(BANK_DIR, sid + ".json")
    return path if os.path.exists(path) else None


# ------------------------------------------------------------------ HTTP

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, fmt, *args):
        if args and isinstance(args[0], str) and "/api/" in args[0]:
            super().log_message(fmt, *args)

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n).decode("utf-8") or "{}") if n else {}

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(u.query)
        if u.path == "/":
            self.send_response(302)
            self.send_header("Location", "/Synapse.html")
            self.end_headers()
            return
        if u.path == "/api/search":
            return self.send_json(search((qs.get("q") or [""])[0].strip()))
        if u.path == "/api/audio":
            return self.proxy_audio((qs.get("url") or [""])[0])
        if u.path == "/api/bank":
            return self.send_json({"scenes": bank_list()})
        if u.path == "/api/bank/get":
            path = bank_path((qs.get("id") or [""])[0])
            if not path:
                return self.send_json({"error": "scene introuvable"}, 404)
            with open(path, encoding="utf-8") as f:
                return self.send_json(json.load(f))
        if u.path == "/api/images":
            try:
                page = max(1, min(12, int((qs.get("page") or ["1"])[0])))
            except ValueError:
                page = 1
            return self.send_json(search_images((qs.get("q") or [""])[0].strip(), page))
        if u.path == "/api/media":
            return self.proxy_media((qs.get("url") or [""])[0])
        if u.path == "/api/videos":
            try:
                page = max(1, min(12, int((qs.get("page") or ["1"])[0])))
            except ValueError:
                page = 1
            return self.send_json(search_videos((qs.get("q") or [""])[0].strip(), page))
        if u.path == "/api/config":
            try:
                import anthropic  # noqa: F401
                sdk = True
            except ImportError:
                sdk = False
            return self.send_json({"freesound": bool(freesound_key()), "anthropic_key": bool(anthropic_key()),
                                   "anthropic_sdk": sdk})
        if u.path.endswith(".json") and "synapse_config" in u.path:
            return self.send_error(403)
        return super().do_GET()

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        try:
            body = self.read_body()
        except ValueError:
            return self.send_json({"error": "json invalide"}, 400)
        if u.path == "/api/plan":
            prompt = (body.get("prompt") or "").strip()
            if not prompt:
                return self.send_json({"error": "prompt vide"}, 400)
            return self.send_json(plan(prompt))
        if u.path == "/api/bank":
            if not isinstance(body.get("layers"), list):
                return self.send_json({"error": "scene invalide"}, 400)
            for L in body["layers"]:  # l'URL des sons sauvegardes pourra repasser par le proxy
                for c in (L.get("candidates") or []):
                    if isinstance(c, dict) and c.get("url"):
                        _issued.add(c["url"])
            return self.send_json({"id": bank_save(body)})
        if u.path == "/api/bank/delete":
            path = bank_path(body.get("id"))
            if not path:
                return self.send_json({"error": "scene introuvable"}, 404)
            os.remove(path)
            return self.send_json({"ok": True})
        if u.path == "/api/config":
            cfg = load_config()
            for k in ("freesound_key", "anthropic_key"):
                if k in body:
                    v = (body[k] or "").strip()
                    if v:
                        cfg[k] = v
                    else:
                        cfg.pop(k, None)
            save_config(cfg)
            return self.send_json({"ok": True})
        self.send_error(404)

    def proxy_audio(self, url):
        host = urllib.parse.urlparse(url).hostname or ""
        if not any(host == h or host.endswith("." + h) for h in AUDIO_HOSTS):
            return self.send_error(403, "hote non autorise")
        try:
            data, ctype = fetch_audio(url)
        except RateLimited:
            return self.send_json({"error": "rate-limit"}, 503)
        except Exception as e:
            return self.send_json({"error": str(e)[:100]}, 502)
        if len(data) > MAX_AUDIO_BYTES:
            return self.send_error(413)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "max-age=86400")
        self.end_headers()
        self.wfile.write(data)

    def proxy_media(self, url):
        if url not in _issued:
            return self.send_error(403, "url non issue d'une recherche")
        video = "/transcoded/" in url or url.lower().endswith((".webm", ".ogv", ".mp4", ".mov"))
        limit = MAX_VIDEO_BYTES if video else MAX_IMAGE_BYTES
        try:
            data, ctype = fetch_audio(url, limit)
        except RateLimited:
            return self.send_json({"error": "rate-limit"}, 503)
        except Exception as e:
            return self.send_json({"error": str(e)[:100]}, 502)
        if video and not ctype.startswith("video/"):
            ctype = "video/webm"
        if len(data) > limit or not (ctype.startswith("image/") or ctype.startswith("video/")):
            return self.send_error(415)
        # requetes partielles (Range) : le navigateur peut sauter n'importe ou dans la video
        total, rng = len(data), self.headers.get("Range")
        m = re.match(r"bytes=(\d*)-(\d*)", rng or "")
        if m and (m.group(1) or m.group(2)):
            if m.group(1):
                a = int(m.group(1)); b = int(m.group(2)) if m.group(2) else total - 1
            else:
                a = max(0, total - int(m.group(2))); b = total - 1
            b = min(b, total - 1)
            if a > b:
                self.send_response(416); self.send_header("Content-Range", f"bytes */{total}"); self.end_headers(); return
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {a}-{b}/{total}")
            body = data[a:b + 1]
        else:
            self.send_response(200)
            body = data
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "max-age=86400")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (ConnectionError, OSError):
            pass


class RateLimited(Exception):
    pass


def fetch_audio(url, limit=MAX_AUDIO_BYTES):
    """Telecharge (avec cache disque + retries sur 429) et renvoie (octets, content-type)."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    h = hashlib.sha1(url.encode("utf-8")).hexdigest()
    path = os.path.join(CACHE_DIR, h)
    if os.path.exists(path):
        with open(path + ".type", encoding="utf-8") as f:
            ctype = f.read().strip()
        with open(path, "rb") as f:
            return f.read(), ctype
    wiki = "wikimedia.org" in (urllib.parse.urlparse(url).hostname or "")
    for attempt in range(3):
        with (_dl_lock if wiki else _no_lock):
            # les vignettes (thumb.wikimedia.org, cache CDN) supportent un rythme un peu plus soutenu
            gap = _dl_last[0] + (0.5 if "thumb" in url else MIN_GAP) - time.time()
            if wiki and gap > 0:
                time.sleep(gap)
            try:
                req = urllib.request.Request(url, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=40) as r:
                    data = r.read(limit + 1)
                    ctype = r.headers.get("Content-Type", "application/octet-stream")
                break
            except urllib.error.HTTPError as e:
                if e.code != 429:
                    raise
                if attempt == 2:
                    raise RateLimited()
                try:
                    wait = float(e.headers.get("Retry-After") or 0)
                except ValueError:
                    wait = 0
                wait = min(wait or 3.0 * (attempt + 1), 10)
            finally:
                if wiki:
                    _dl_last[0] = time.time()
        time.sleep(wait)
    if len(data) <= limit:
        with open(path, "wb") as f:
            f.write(data)
        with open(path + ".type", "w", encoding="utf-8") as f:
            f.write(ctype)
    return data, ctype


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"SYNAPSE -> http://localhost:{PORT}/Synapse.html")
    print("  Freesound :", "cle API" if freesound_key() else "sans cle, via Openverse")
    print("  Claude    :", "cle presente" if anthropic_key() else "analyseur local FR->EN")
    Server(("127.0.0.1", PORT), Handler).serve_forever()
