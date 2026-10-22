"""Generate mcl-mail's two C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: what the service talks to
  c4-components.svg  Level 2: what it is made of

Drawn from the code, never from a template: the callbacks and capabilities/0 in
apps/mcl_mail/src/mcl_mail_service.erl, the boot order in mcl_mail_app.erl, the store
wiring in mcl_mail_store.erl, the four apps and the deps in rebar.config, the org and
the pinned-realm settings in config/sys.config.src, the volumes in deploy/
docker-compose.yml, and the health socket in the Containerfile. When one of those
changes, the diagram changes in the same commit.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS custom
properties (rsvg-convert renders those black), so the SVGs render the same on
GitHub, in IDE previews and through rsvg-convert. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # Macula infrastructure
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Macula infrastructure"),
          ("b-ext", "External system"), ("b-cmp", "Container or component")]
BOUNDARY = ("bound", "Boundary")


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def box(self, cls, x, y, w, h, name, kind, desc, person=False, code=False):
        # A box that is too small for its own words renders as text on top of the
        # next box, which no test would catch and a reader would read as the
        # diagram saying something it does not. Fail here instead.
        need = 70 + 16 * max(len(desc) - 1, 0) + 18
        if h < need:
            raise ValueError(f"{self.name}: {name} needs height {need}, has {h}")
        for line in desc:
            if 16 + 6.2 * len(line) > w - 16:
                raise ValueError(f"{self.name}: {name}: '{line}' is wider than {w - 32}px")
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)

    def bound(self, x, y, w, h, label):
        self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
        self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, later=False):
        self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')

    def legend(self, y, boundary=True):
        x = 24
        for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
            self.text("t-leg", x + 30, y + 12, label)
            x += 34 + 6.6 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "mcl-mail system context", 1000, 690)
    d.box("b-per", 40, 30, 270, 120, "Citizen", "[Person]",
          ["A person, an agent or a service", "with a Macula node identity;", "reads and replies from its mail"],
          person=True)
    d.box("b-per", 365, 30, 270, 120, "Correspondent", "[Person]",
          ["Any mesh caller: an agent", "leaving work for a citizen", "who is not online right now"],
          person=True)
    d.box("b-ext", 690, 30, 270, 120, "macula-fleet", "[External system]",
          ["Pins each signed v* release", "by digest, canary first; no", "tag moves and main deploys nothing"])
    d.box("b-sys", 365, 186, 270, 152, "mcl-mail", "[mcl_om mesh service]",
          ["Serves 7 procedures under", "mcl-mail/*, each acting as the", "CALL's caller. Its store and",
           "read model are local files under", "MCL_DATA_DIR; /health is a socket"])
    d.box("b-mac", 365, 430, 270, 120, "macula-realm", "[Macula infrastructure]",
          ["The trust anchor: its public key", "is pinned, its grant names the", "org mcl-mail, and it sees the claim"])
    d.box("b-mac", 690, 430, 270, 120, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["The pinned dial: each seed pairs", "with its station node id, and the", "DHT takes each advertisement"])
    d.edge("M175 150V168H400V186")
    d.text("t-rel", 183, 160, "calls initiate_mailbox,")
    d.text("t-rel", 183, 176, "get_mailbox, get_letter")
    d.edge("M500 150V186"); d.text("t-rel", 508, 164, "calls deposit_letter")
    d.edge("M825 150V168H620V186"); d.text("t-rel", 640, 160, "pins the signed release")
    d.edge("M460 338V430"); d.text("t-rel", 468, 384, "trust anchor, grant")
    d.edge("M620 338V370H825V430"); d.text("t-rel", 632, 364, "pinned seeds, dial")
    d.text("t-desc", 40, 596, "It calls nothing outside the mesh: no HTTP client, no SMTP, no database server. The store and the letter")
    d.text("t-desc", 40, 614, "read model are local files under MCL_DATA_DIR. A DID is a Macula node id, and macula puts the signing")
    d.text("t-desc", 40, 632, "caller on every CALL, so every procedure acts as that citizen and nothing in a payload can name another.")
    d.legend(650, boundary=False)
    d.write()


def components():
    d = Diagram("c4-components.svg", "mcl-mail components", 1040, 1310)
    d.bound(40, 40, 968, 970, "mcl-mail [Container]")
    d.box("b-cmp", 56, 70, 456, 120, "mcl_mail_app", "[OTP application]",
          ["start/2 opens mcl_mail_store, then calls", "mcl_om:boot(mcl_mail_service) to wire the mesh.",
           "mcl_om opens no store from 0.35 (mcl-om#10)."], code=True)
    d.box("b-sys", 536, 70, 456, 120, "mcl_mail_service", "[:mcl_om_service behaviour]",
          ["info, start, stop, health, capabilities and", "identity_spec. Seven procedures, each served",
           "under its own grant; scope mcl-mail, 30 days."], code=True)
    d.box("b-cmp", 56, 230, 456, 120, "mcl_mail_store", "[Erlang module]",
          ["Starts mcl_mail_store under MCL_DATA_DIR, waits", "until reckon_db lists it, then starts evoq's",
           "per-store subscription (reckon_db ~> 5.11)."], code=True)
    d.box("b-cmp", 536, 230, 456, 120, "Seven responders", "[macula_response, one each]",
          ["initiate, open, deposit, reply and archive (in", "guide_mailbox_lifecycle); get_mailbox and",
           "get_letter (in query_mailboxes). No topics."], code=True)
    d.box("b-cmp", 56, 390, 456, 120, "mcl_mail_sup", "[supervisor, one_for_one]",
          ["start_link/0, called by Service.start/1.", "No children: each department supervises its",
           "own processes and macula spawns a responder."], code=True)
    d.box("b-cmp", 536, 390, 456, 120, "mailbox_citizen", "[Erlang module]",
          ["Who a CALL acts as. macula puts the signing", "node id on every CALL; caller/1 reads it and",
           "did/1 takes a DID as 64 hex or 32 raw bytes."], code=True)
    d.box("b-cmp", 56, 550, 456, 120, "guide_mailbox_lifecycle", "[CMD app, Erlang]",
          ["mailbox_aggregate, mailbox_state and nine", "desks; one stream per citizen, mailbox-<digest>.",
           "Status is bit flags (mailbox_status.hrl)."], code=True)
    d.box("b-cmp", 536, 550, 456, 120, "project_mailboxes", "[PRJ app, Erlang]",
          ["letter_lifecycle_to_mailboxes projects the", "four letter events into one document per letter.",
           "Starts before the subscription replays."], code=True)
    d.box("b-cmp", 56, 710, 456, 120, "query_mailboxes", "[QRY app, Erlang]",
          ["get_mailbox and get_letter, read straight", "from mailboxes_read_model. Marking a fetched",
           "letter read is folded into both."], code=True)
    d.box("b-cmp", 536, 710, 456, 120, "mailboxes_read_model", "[barrel_docdb, database mcl_mail]",
          ["One document per letter, keyed by the citizen", "and the letter id; opened by project_mailboxes",
           "at boot. barrel_docdb ~> 1.5, on rocksdb."], code=True)
    d.box("b-mac", 56, 870, 456, 120, "mcl_om", "[library, ~> 1.4]",
          ["boot/1: loads the identity key, joins the", "realm, dials the pinned stations, advertises the",
           "procedures, serves /health on a socket."], code=True)
    d.box("b-mac", 536, 870, 456, 120, "macula SDK", "[library, ~> 16.0, wire 1.0]",
          ["QUIC transport, RPC dispatch to a named", "responder, and the caller field every station on",
           "the path verifies before a handler runs."], code=True)
    d.edge("M56 130H16V930H56"); d.text("t-rel", 30, 530, "calls mcl_om:boot/1", anchor="middle", rotate=-90)
    d.edge("M512 130H536"); d.text("t-rel", 524, 122, "boots", anchor="middle")
    d.edge("M284 190V230"); d.text("t-rel", 292, 216, "opens, subscribes")
    d.edge("M804 190V230"); d.text("t-rel", 812, 216, "capabilities/0 names 7")
    d.edge("M864 350V390"); d.text("t-rel", 872, 374, "caller, DID")
    d.edge("M536 290H520V530H284V550"); d.text("t-rel", 330, 546, "command, desk")
    d.edge("M512 610H536"); d.text("t-rel", 524, 602, "events", anchor="middle")
    d.edge("M864 670V710"); d.text("t-rel", 872, 694, "writes a document")
    d.edge("M512 770H536"); d.text("t-rel", 524, 762, "reads", anchor="middle")
    d.edge("M512 930H536"); d.text("t-rel", 524, 922, "dials", anchor="middle")
    d.box("b-ext", 64, 1040, 920, 136, "Host environment", "[read at boot; nothing here is baked into the image]",
          ["MCL_REALM and MCL_REALM_KEY are required: the realm tag and its public key, the trust anchor. MACULA_STATION_SEEDS with",
           "MACULA_STATION_NODE_IDS is the pinned dial: each seed pairs with its station's node id. MCL_DATA_DIR holds the store, the read model",
           "and barrel_docdb's system database. MCL_COOKIE and MCL_NODE_NAME name the node; MCL_SERVICE_NAME and MCL_BOX label the boot claim."],
          code=True)
    d.text("t-desc", 64, 1212, "config/sys.config.src sets mesh: required, so a boot missing the realm, its key or the pinned stations stops and names each one.")
    d.text("t-desc", 64, 1230, "The store id, mcl_mail_store, is named in event_store/0 and in the evoq block; a test compares them, and a second asserts the block is there.")
    d.text("t-desc", 64, 1248, "deploy/docker-compose.yml mounts /etc/mcl/secrets for the node key and a host directory on /data, on a bulk drive; a recreate without them loses both.")
    d.legend(1272)
    d.write()


if __name__ == "__main__":
    for make in (context, components):
        make()
