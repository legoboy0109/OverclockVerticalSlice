#!/usr/bin/env python3
"""build_data.py — turns the game-data/ Obsidian vault into the game's .tres data files.

The vault is the SOURCE OF TRUTH for units, structures, techs, factions and maps. Every
note's YAML frontmatter (Obsidian "Properties") is validated against the schema below and
written to data/<kind>/<id>.tres. Map notes also carry a text grid in a ```map block.

Usage:
    python3 tools/vault/build_data.py            # regenerate every data file
    python3 tools/vault/build_data.py --check    # exit 1 if any data file is stale

Why generate .tres rather than have the game read the notes: the game's code compares
data by object IDENTITY (`type == UnitTypes.TROOPER`), which relies on each file being a
preloaded engine resource. Generating keeps all of that untouched, keeps the notes out
of the shipped game, and lets this script refuse bad data with a readable message
before the game ever sees it.

Every generated file carries `; source-sha256: <hash of the note>`. The GdUnit test
tests/unit/data/vault_sync_test.gd recomputes it, so a note edited without
regenerating fails the suite with the command to run.

Identity: each note has an `id` property — the data file's name and what code refers
to. The note's TITLE is the in-game display name, so a note can be renamed freely
(Obsidian updates links) without breaking any code reference.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
VAULT = ROOT / "game-data"
DATA = ROOT / "data"

LINK_RE = re.compile(r"^\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]$")


class VaultError(Exception):
    pass


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

@dataclass
class Field:
    name: str
    kind: str                 # int | bool | str | enum | link | links | group | deltas
    default: object = None
    required: bool = False
    target: str = ""          # for link/links: the vault folder the link must point into
    choices: dict = field(default_factory=dict)   # for enum: label -> int
    help: str = ""
    lo: int | None = None     # inclusive bounds for int fields, checked at build time
    hi: int | None = None


@dataclass
class Kind:
    folder: str               # vault folder
    data_dir: str             # data/<data_dir>/<id>.tres
    script: str               # res:// path of the Resource script
    script_class: str
    fields: list[Field]
    title_field: str = "display_name"   # frontmatter never sets this; it is the note title


TARGETING = {"direct": 0, "area": 1}
UNIT_CLASS = {"infantry": 0, "ground_vehicle": 1, "air": 2}
DAMAGE_TYPE = {"kinetic": 0, "emf": 1, "incendiary": 2}
AREA_SHAPE = {"single": 0, "burst": 1, "line": 2}
RES_LO, RES_HI = -3, 3        # damage-types.md RESISTANCE_MIN/MAX — outside it, types become hard counters


def damage_fields(with_area: bool) -> list:
    out = [
        Field("damage_type", "enum", "kinetic", choices=DAMAGE_TYPE, help="kinetic | emf | incendiary"),
        Field("resist_kinetic", "int", 0, lo=RES_LO, hi=RES_HI, help="Subtracted from incoming damage; negative = weak to"),
        # None = the class default (DT-9b): machines -2 (EMF is the anti-armour type), infantry +2.
        Field("resist_emf", "int", None, lo=RES_LO, hi=RES_HI, help="Blank = class default (machines -2, infantry +2)"),
        Field("resist_incendiary", "int", 0, lo=RES_LO, hi=RES_HI),
    ]
    if with_area:
        out += [Field("area_shape", "enum", "single", choices=AREA_SHAPE, help="single | burst | line"),
                Field("area_length", "int", 4, lo=1, hi=8, help="Tiles, for line attacks")]
    return out

KINDS: dict[str, Kind] = {
    "Units": Kind("Units", "units", "res://src/core/unit/unit_type_def.gd", "UnitTypeDef", [
        Field("unit_class", "enum", "infantry", choices=UNIT_CLASS, help="infantry | ground_vehicle | air"),
        Field("can_target", "enums", ["infantry", "ground_vehicle"], choices=UNIT_CLASS,
              help="Classes it can attack; structures count as ground targets. [] = unarmed"),
        Field("hp", "int", required=True, help="Hit points"),
        Field("attack", "int", required=True),
        Field("attack_range", "int", required=True, help="0 = cannot attack"),
        Field("defense", "int", 0),
        Field("move_cost", "int", required=True, help="AP per tile moved"),
        Field("soft_move_cap", "int", required=True, help="Tiles before the move surcharge starts"),
        Field("produce_cost", "int", required=True, help="Credits"),
        Field("production_turns", "int", 1),
        Field("max_ammo", "int", -1, lo=-1, hi=20,
              help="Attacks before resupply; -1 = class default (vehicles 4, aircraft 3, infantry unlimited); 0 = unlimited"),
        Field("upkeep", "int", 0, help="Credits per turn"),
        Field("counts_toward_cap", "bool", True),
        Field("can_counterattack", "bool", False),
        Field("can_build", "bool", False),
        Field("targeting_mode", "enum", "direct", choices=TARGETING),
        Field("min_range", "int", 1),
    ] + damage_fields(True) + [
        Field("abilities", "links", [], target="Abilities", help="Catalogue entries this unit carries"),
        Field("can_pilot", "bool", False, help="May crew a vehicle (infantry only)"),
        Field("requires_pilot", "bool", False, help="Inert until an infantry pilot climbs in"),
        Field("transport_capacity", "int", 0, lo=0, hi=6, help="Passenger slots; 0 = not a transport"),
        Field("transport_accepts", "enums", [], choices=UNIT_CLASS, help="Classes it can carry"),
        Field("transport_size", "int", 1, lo=1, hi=6, help="Slots this unit takes as a passenger"),
        Field("targets_crew", "bool", False, help="Its attacks hit a vehicle's pilot, not the vehicle"),
        Field("crew_bonus_attack", "int", 0, lo=-1, hi=1, help="Attack it adds to a vehicle it pilots (TP-5d: at most +1)"),
        Field("starting_merit", "int", 0, lo=0, hi=40, help="Merit it is produced with (a promoting faction's veterans)"),
        Field("crew_bonus_move_cost", "int", 0, lo=-1, hi=0, help="Move cost it takes off a vehicle it pilots (TP-5d: at most -1)"),
        Field("art_id", "group", "", help="Borrow another unit's sprites (its id) until this has art"),
    ]),
    "Structures": Kind("Structures", "structures", "res://src/core/structure/structure_type_def.gd",
                       "StructureTypeDef", [
        Field("buildable", "bool", False, help="In the SHARED roster (factions with their own list ignore it)"),
        Field("art_id", "group", "", help="Borrow another structure's sprites (its id) until this has art"),
        Field("counts_as", "links", [], target="Structures", help="Stands in for these types when a rule asks (e.g. a faction's Research Lab)"),
        Field("hp", "int", required=True),
        Field("build_cost", "int", required=True, help="Credits"),
        Field("build_time", "int", required=True, help="Owner-turns"),
        Field("upkeep", "int", 0),
        Field("max_count", "int", 0, help="0 = unlimited"),
        Field("cap_bonus", "int", 0, help="Population cap it grants"),
        Field("production_cap", "int", 0, help="Units per turn"),
        Field("produces", "links", [], target="Units"),
        Field("attack", "int", 0),
        Field("attack_range", "int", 0),
        Field("defense", "int", 0),
        Field("can_counterattack", "bool", False),
        Field("can_research", "bool", False),
        Field("resupplies", "bool", False, help="Refills ammo of own units beside it each turn"),
        Field("can_target", "enums", ["infantry", "ground_vehicle"], choices=UNIT_CLASS),
        Field("targeting_mode", "enum", "direct", choices=TARGETING),
        Field("min_range", "int", 1),
    ] + damage_fields(False)),
    "Techs": Kind("Techs", "techs", "res://src/core/research/tech_def.gd", "TechDef", [
        Field("description", "str", "", help="Shown in the research picker"),
        Field("tier", "int", 1),
        Field("research_cost", "int", required=True),
        Field("research_time", "int", required=True),
        Field("ap_surcharge", "int", -1, help="-1 = the economy default"),
        Field("requires", "links", [], target="Techs"),
        Field("requires_structures", "links", [], target="Structures"),
        Field("exclusive_group", "group", ""),
        Field("factions", "links", [], target="Factions", help="Empty = every faction"),
        Field("attack_bonus", "int", 0),
        Field("defense_bonus", "int", 0),
        Field("attack_range_bonus", "int", 0),
        Field("ignores_cover", "bool", False),
        Field("idle_heal", "int", 0),
        Field("economy_tier_bonus", "int", 0),
        Field("produce_ap_discount", "int", 0),
        Field("build_ap_discount", "int", 0),
        Field("produce_cost_discount_pct", "int", 0),
        Field("frees_pilots", "links", [], target="Units", help="Unit types that stop needing a pilot"),
        Field("vehicle_attack_bonus", "int", 0, help="Attack added to ground vehicles only"),
        Field("vehicle_defense_bonus", "int", 0, help="Defence added to ground vehicles only"),
    ]),
    "Factions": Kind("Factions", "factions", "res://src/core/faction/faction_def.gd", "FactionDef", [
        Field("description", "str", ""),
        Field("playable", "bool", False, help="Offered in the faction picker"),
        Field("hq", "link", None, target="Structures", help="This faction's HQ; blank = the shared HQ"),
        Field("structures", "links", [], target="Structures", help="What its Builders may raise; empty = shared roster"),
        Field("techs", "links", [], target="Techs", help="Its tech tree; empty = shared tree"),
        Field("infantry_cap_delta", "int", 0, lo=-4, hi=6, help="Added to the base infantry cap"),
        Field("base_income_delta", "int", 0, lo=-500, hi=1000, help="Added to base Credit income per turn"),
        Field("econ_tier_bonus_delta", "int", 0, lo=-400, hi=500, help="Added to each economy tier's bonus"),
        Field("upkeep_pct_delta", "int", 0, lo=-50, hi=100, help="Percent added to all upkeep"),
        Field("vehicle_upkeep_pct_delta", "int", 0, lo=-90, hi=200, help="Percent added to vehicle (ground and air) upkeep only"),
        Field("unit_changes", "deltas", []),
        Field("promotes", "bool", False, help="Units earn merit and rank up (Empire only, for now)"),
        Field("rank_requires_support", "bool", False, help="Ranks drop without a support structure"),
        Field("rank_support_structures", "links", [], target="Structures"),
    ]),
    "Abilities": Kind("Abilities", "abilities", "res://src/core/ability/ability_def.gd", "AbilityDef", [
        Field("description", "str", ""),
        Field("ap_cost", "int", required=True, lo=1, hi=20, help="No free abilities (AB-3)"),
        Field("credit_cost", "int", 0, lo=0),
        Field("ability_range", "int", required=True, lo=0, hi=10, help="0 = self"),
        Field("cooldown", "int", 0, lo=0),
        Field("uses_per_match", "int", 0, lo=0, help="0 = unlimited"),
        Field("amount", "int", 0, help="The magnitude: hp, defence, damage"),
    ]),
    "Maps": Kind("Maps", "maps", "res://src/core/grid/map_definition.gd", "MapDefinition", []),
}

# Vault property name -> Resource property name, where they differ. The vault uses the
# words a designer would; the Resource keeps the names the code already uses.
RENAMES = {
    ("Structures", "produces"): "producible_types",
    ("Techs", "requires"): "prerequisites",
    ("Techs", "requires_structures"): "required_structures",
    ("Techs", "factions"): "allowed_factions",
    ("Factions", "unit_changes"): "unit_deltas",
}

MAP_LEGEND = {".": 0, "c": 1, "#": 2, "r": 3, "A": 0, "B": 0}   # GridState.Terrain PLAIN/COVER/IMPASSABLE/ROUGH
MAP_MIN, MAP_MAX = 8, 24


# ---------------------------------------------------------------------------
# Reading the vault
# ---------------------------------------------------------------------------

@dataclass
class Note:
    kind: str
    title: str
    path: Path
    props: dict
    body: str
    sha: str

    @property
    def id(self) -> str:
        return self.props["id"]

    @property
    def rel(self) -> str:
        return self.path.relative_to(ROOT).as_posix()


def read_note(kind: str, path: Path) -> Note:
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        raise VaultError(f"{path.relative_to(ROOT)}: no properties block (the --- lines at the top)")
    try:
        props = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        raise VaultError(f"{path.relative_to(ROOT)}: properties are not valid YAML: {e}")
    if not isinstance(props, dict):
        raise VaultError(f"{path.relative_to(ROOT)}: properties must be key: value pairs")
    return Note(kind, path.stem, path, props, m.group(2), hashlib.sha256(raw).hexdigest())


def read_vault() -> dict[str, list[Note]]:
    notes: dict[str, list[Note]] = {}
    for kind in KINDS:
        folder = VAULT / kind
        notes[kind] = sorted((read_note(kind, p) for p in folder.glob("*.md")), key=lambda n: n.title) \
            if folder.is_dir() else []
    return notes


# ---------------------------------------------------------------------------
# Validation + value conversion
# ---------------------------------------------------------------------------

def link_target(value: object, where: str) -> str:
    if not isinstance(value, str) or not LINK_RE.match(value.strip()):
        raise VaultError(f'{where}: expected a link like "[[Trooper]]", got {value!r}')
    return LINK_RE.match(value.strip()).group(1).strip()


def resolve(title: str, target: str, index: dict, where: str) -> Note:
    note = index[target].get(title)
    if note is None:
        known = ", ".join(sorted(index[target])) or "none"
        raise VaultError(f"{where}: [[{title}]] is not a note in {target}/ (known: {known})")
    return note


def validate(note: Note, index: dict) -> dict:
    """Returns {resource_property: python value or ('link', Note) / ('links', [Note])}."""
    kind = KINDS[note.kind]
    where = note.rel
    props = dict(note.props)
    out: dict = {}
    nid = props.pop("id", None)
    if not isinstance(nid, str) or not re.fullmatch(r"[a-z0-9_]+", nid or ""):
        raise VaultError(f"{where}: needs an `id` property of lowercase letters, digits and _ "
                         f"(it names the data file code refers to), got {nid!r}")
    props.pop("tags", None)          # Obsidian's own; allowed and ignored
    props.pop("notes", None)         # free-text property for designers; ignored
    known = {f.name for f in kind.fields}
    unknown = set(props) - known
    if unknown:
        raise VaultError(f"{where}: unknown propert{'y' if len(unknown) == 1 else 'ies'} "
                         f"{sorted(unknown)} — allowed: {sorted(known)}")
    for f in kind.fields:
        present = f.name in props and props[f.name] is not None
        if f.required and not present:
            raise VaultError(f"{where}: `{f.name}` is required" + (f" ({f.help})" if f.help else ""))
        value = props[f.name] if present else f.default
        key = RENAMES.get((note.kind, f.name), f.name)
        w = f"{where} `{f.name}`"
        if f.name == "resist_emf" and value is None:
            # DT-9b: machines are EMF-vulnerable, flesh is EMF-resistant, unless overridden.
            is_infantry = note.kind != "Units" or str(props.get("unit_class", "infantry")).lower() == "infantry"
            value = 0 if note.kind == "Structures" else (2 if is_infantry else -2)
        if f.kind == "int":
            if isinstance(value, bool) or not isinstance(value, int):
                raise VaultError(f"{w}: expected a whole number, got {value!r}")
            if (f.lo is not None and value < f.lo) or (f.hi is not None and value > f.hi):
                raise VaultError(f"{w}: {value} is outside the allowed {f.lo} to {f.hi}"
                                 + (f" ({f.help})" if f.help else ""))
            out[key] = value
        elif f.kind == "bool":
            if not isinstance(value, bool):
                raise VaultError(f"{w}: expected true/false (a checkbox), got {value!r}")
            out[key] = value
        elif f.kind == "str":
            out[key] = "" if value is None else str(value)
        elif f.kind == "group":
            s = "" if value is None else str(value)
            if s and not re.fullmatch(r"[a-z0-9_]+", s):
                raise VaultError(f"{w}: use lowercase letters, digits and _ (got {s!r})")
            out[key] = ("group", s)
        elif f.kind == "enum":
            if str(value).lower() not in f.choices:
                raise VaultError(f"{w}: must be one of {sorted(f.choices)}, got {value!r}")
            out[key] = f.choices[str(value).lower()]
        elif f.kind == "enums":
            if value is None:
                value = []
            if not isinstance(value, list) or any(str(v).lower() not in f.choices for v in value):
                raise VaultError(f"{w}: expected a list drawn from {sorted(f.choices)}, got {value!r}")
            out[key] = ("ints", [f.choices[str(v).lower()] for v in value])
        elif f.kind == "link":
            out[key] = ("links1", resolve(link_target(value, w), f.target, index, w) if value else None)
        elif f.kind == "links":
            if value is None:
                value = []
            if isinstance(value, str):
                value = [value]
            if not isinstance(value, list):
                raise VaultError(f"{w}: expected a list of links")
            out[key] = ("links", [resolve(link_target(v, w), f.target, index, w) for v in value])
        elif f.kind == "deltas":
            rows = []
            for i, row in enumerate(value or []):
                rw = f"{w}[{i + 1}]"
                if not isinstance(row, dict) or "unit" not in row:
                    raise VaultError(f'{rw}: each entry needs `unit: "[[Name]]"` plus changes')
                extra = set(row) - {"unit", "cost", "move_cost"}
                if extra:
                    raise VaultError(f"{rw}: unknown keys {sorted(extra)} — allowed: unit, cost, move_cost")
                unit = resolve(link_target(row["unit"], rw), "Units", index, rw)
                for k in ("cost", "move_cost"):
                    if k in row and (isinstance(row[k], bool) or not isinstance(row[k], int)):
                        raise VaultError(f"{rw} `{k}`: expected a whole number")
                rows.append((unit, int(row.get("cost", 0)), int(row.get("move_cost", 0))))
            out[key] = ("deltas", rows)
    return out


def parse_map(note: Note) -> dict:
    where = note.rel
    m = re.search(r"```map\n(.*?)```", note.body, re.S)
    if not m:
        raise VaultError(f"{where}: needs a ```map block drawing the board")
    rows = [re.sub(r"\s+", "", line) for line in m.group(1).splitlines() if line.strip()]
    height = len(rows)
    width = len(rows[0]) if rows else 0
    if any(len(r) != width for r in rows):
        raise VaultError(f"{where}: every map row must be the same width "
                         f"(row lengths: {[len(r) for r in rows]})")
    if not (MAP_MIN <= width <= MAP_MAX and MAP_MIN <= height <= MAP_MAX):
        raise VaultError(f"{where}: board is {width}x{height}; each side must be {MAP_MIN}-{MAP_MAX}")
    terrain, hqs = [], {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in MAP_LEGEND:
                raise VaultError(f"{where}: unknown map symbol {ch!r} at column {x + 1}, row {y + 1} "
                                 f"— use . (open), c (cover), r (rough), # (blocked), A/B (HQs)")
            terrain.append(MAP_LEGEND[ch])
            if ch in "AB":
                if ch in hqs:
                    raise VaultError(f"{where}: more than one {ch} (each player has exactly one HQ)")
                hqs[ch] = (x, y)
    if set(hqs) != {"A", "B"}:
        raise VaultError(f"{where}: the map needs exactly one A (player 1 HQ) and one B (player 2 HQ)")
    return {"width": width, "height": height, "terrain": terrain, "hqs": [hqs["A"], hqs["B"]]}


# ---------------------------------------------------------------------------
# Writing .tres
# ---------------------------------------------------------------------------

def gd_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def res_path(note: Note) -> str:
    return f"res://data/{KINDS[note.kind].data_dir}/{note.id}.tres"


def render(note: Note, index: dict) -> str:
    kind = KINDS[note.kind]
    ext: list[tuple[str, str]] = [("Script", kind.script)]
    subs: list[str] = []

    def ext_id(type_: str, path: str) -> str:
        for i, (t, p) in enumerate(ext):
            if p == path:
                return str(i + 1)
        ext.append((type_, path))
        return str(len(ext))

    lines = [f"display_name = {gd_str(note.title)}"]
    if note.kind == "Abilities":
        lines.append(f'id = &"{note.id}"')   # the effect code dispatches on this
    if note.kind == "Maps":
        mp = parse_map(note)
        rl = note.props.get("round_limit", 80)
        if not isinstance(rl, int) or isinstance(rl, bool) or not 20 <= rl <= 200:
            raise VaultError(f"{note.rel}: round_limit must be a whole number from 20 to 200 (got {rl!r})")
        ap = note.props.get("ap_per_turn", 20)
        if not isinstance(ap, int) or isinstance(ap, bool) or not 10 <= ap <= 40:
            raise VaultError(f"{note.rel}: ap_per_turn must be a whole number from 10 to 40 (got {ap!r})")
        lines += [
            f"default_round_limit = {rl}",
            f"default_ap_per_turn = {ap}",
            f"description = {gd_str(str(note.props.get('description', '')))}",
            f"width = {mp['width']}",
            f"height = {mp['height']}",
            "mode = 0",
            "authored_terrain = PackedByteArray(" + ", ".join(map(str, mp["terrain"])) + ")",
            "hq_tiles = [" + ", ".join(f"Vector2i({x}, {y})" for x, y in mp["hqs"]) + "]",
            "deploy_tiles = []",
        ]
    else:
        for key, value in validate(note, index).items():
            if isinstance(value, bool):
                lines.append(f"{key} = {'true' if value else 'false'}")
            elif isinstance(value, int):
                lines.append(f"{key} = {value}")
            elif isinstance(value, str):
                lines.append(f"{key} = {gd_str(value)}")
            elif value[0] == "ints":
                lines.append(f"{key} = Array[int]([{', '.join(map(str, value[1]))}])")
            elif value[0] == "group":
                lines.append(f'{key} = &{gd_str(value[1])}')
            elif value[0] == "links1":
                if value[1] is not None:
                    lines.append(f'{key} = ExtResource("{ext_id("Resource", res_path(value[1]))}")')
            elif value[0] == "links":
                refs = [f'ExtResource("{ext_id("Resource", res_path(n))}")' for n in value[1]]
                lines.append(f"{key} = [{', '.join(refs)}]")
            elif value[0] == "deltas":
                refs = []
                delta_script = ext_id("Script", "res://src/core/faction/faction_unit_delta.gd")
                for i, (unit, cost, move) in enumerate(value[1]):
                    sid = f"delta_{i + 1}"
                    subs.append(
                        f'[sub_resource type="Resource" id="{sid}"]\n'
                        f'script = ExtResource("{delta_script}")\n'
                        f'type = ExtResource("{ext_id("Resource", res_path(unit))}")\n'
                        f"cost_delta = {cost}\nmove_cost_delta = {move}\n")
                    refs.append(f'SubResource("{sid}")')
                lines.append(f"{key} = [{', '.join(refs)}]")
    header = (f'[gd_resource type="Resource" script_class="{kind.script_class}" '
              f'load_steps={len(ext) + len(subs) + 1} format=3]\n')
    out = [header,
           f"; GENERATED from {note.rel} — edit the note, then run: python3 tools/vault/build_data.py\n",
           f"; source-sha256: {note.sha}\n\n"]
    out += [f'[ext_resource type="{t}" path="{p}" id="{i + 1}"]\n' for i, (t, p) in enumerate(ext)]
    out.append("\n")
    for s in subs:
        out += [s, "\n"]
    out += ["[resource]\n", 'script = ExtResource("1")\n'] + [l + "\n" for l in lines]
    return "".join(out)


def build(check: bool) -> int:
    notes = read_vault()
    index = {k: {n.title: n for n in ns} for k, ns in notes.items()}
    errors, stale, written = [], [], 0
    seen_ids: dict[tuple[str, str], str] = {}
    expected: dict[Path, str] = {}
    for kind, ns in notes.items():
        for n in ns:
            try:
                nid = n.props.get("id")
                if (kind, nid) in seen_ids:
                    raise VaultError(f"{n.rel}: id {nid!r} is already used by {seen_ids[(kind, nid)]}")
                seen_ids[(kind, nid)] = n.rel
                if kind == "Maps" and not re.fullmatch(r"[a-z0-9_]+", str(nid)):
                    raise VaultError(f"{n.rel}: needs an `id` property of lowercase letters, digits and _")
                expected[DATA / KINDS[kind].data_dir / f"{nid}.tres"] = render(n, index)
            except VaultError as e:
                errors.append(str(e))
    if errors:
        print("The vault has problems — nothing was written:\n", file=sys.stderr)
        for e in errors:
            print("  ✗ " + e, file=sys.stderr)
        return 2
    for path, text in sorted(expected.items()):
        current = path.read_text("utf-8") if path.exists() else None
        if current != text:
            stale.append(path.relative_to(ROOT).as_posix())
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, "utf-8")
                written += 1
    # A generated file whose note was deleted or renamed-by-id would linger and still load.
    orphans = []
    for kind in KINDS.values():
        for p in (DATA / kind.data_dir).glob("*.tres"):
            if p not in expected and p.read_text("utf-8").find("; GENERATED from") != -1:
                orphans.append(p.relative_to(ROOT).as_posix())
    if check:
        if stale or orphans:
            print("Data files are out of date with the vault:", *stale, *[o + " (no note)" for o in orphans],
                  "Run: python3 tools/vault/build_data.py", sep="\n  ", file=sys.stderr)
            return 1
        print(f"OK — {len(expected)} data files match the vault.")
        return 0
    for o in orphans:
        (ROOT / o).unlink()
    print(f"Wrote {written} of {len(expected)} data files"
          + (f", removed {len(orphans)} orphaned" if orphans else "") + ".")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="fail if any data file is stale; write nothing")
    try:
        sys.exit(build(ap.parse_args().check))
    except VaultError as e:
        print("✗ " + str(e), file=sys.stderr)
        sys.exit(2)
