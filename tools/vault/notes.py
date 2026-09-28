"""Helpers for writing vault notes from scripts (used when adding faction content in bulk).
The vault stays the source of truth — these only produce notes a designer then owns."""
import re
from pathlib import Path
import yaml

VAULT = Path(__file__).resolve().parents[2] / "game-data"

UNIT_DEFAULTS = {"unit_class": "infantry", "can_target": ["infantry", "ground_vehicle"], "hp": 1, "attack": 0,
    "attack_range": 0, "defense": 0, "move_cost": 1, "soft_move_cap": 3, "produce_cost": 100, "production_turns": 1,
    "upkeep": 0, "counts_toward_cap": True, "can_counterattack": False, "can_build": False, "targeting_mode": "direct",
    "min_range": 1, "damage_type": "kinetic", "resist_kinetic": 0, "resist_emf": None, "resist_incendiary": 0,
    "area_shape": "single", "area_length": 4, "abilities": [], "can_pilot": False, "requires_pilot": False,
    "transport_capacity": 0, "transport_accepts": [], "transport_size": 1, "targets_crew": False,
    "crew_bonus_attack": 0, "art_id": ""}

STRUCT_DEFAULTS = {"buildable": False, "art_id": "", "hp": 10, "build_cost": 500, "build_time": 2, "upkeep": 100,
    "max_count": 1, "cap_bonus": 0, "production_cap": 0, "produces": [], "attack": 0, "attack_range": 0,
    "defense": 0, "can_counterattack": False, "can_research": False, "can_target": ["infantry", "ground_vehicle"],
    "targeting_mode": "direct", "min_range": 1, "damage_type": "kinetic", "resist_kinetic": 0, "resist_emf": 0,
    "resist_incendiary": 0}


def slug(title: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")


def write(folder: str, title: str, props: dict, body: str) -> None:
    text = "---\n" + yaml.safe_dump(props, sort_keys=False, allow_unicode=True, width=200).rstrip() + "\n---\n" + body
    (VAULT / folder / f"{title}.md").write_text(text)


def unit(title: str, body: str, **kw) -> None:
    props = {"id": kw.pop("id", slug(title))}
    props.update(UNIT_DEFAULTS)
    if kw.get("unit_class", "infantry") != "infantry":
        props.update(counts_toward_cap=False, transport_size=3)
    props.update(kw)
    if props["resist_emf"] is None:
        props["resist_emf"] = 2 if props["unit_class"] == "infantry" else -2
    write("Units", title, props, body)


def structure(title: str, body: str, **kw) -> None:
    props = {"id": kw.pop("id", slug(title))}
    props.update(STRUCT_DEFAULTS)
    props.update(kw)
    write("Structures", title, props, body)
