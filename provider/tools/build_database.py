#!/usr/bin/env python3
"""Build the experimental, English quest lookup database."""
from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sqlite3
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEP = "\x1f"
ROW = "\x1e"


def normalize_quest_text(value: str) -> str:
    """Create a player-independent key comparable with 1.12 quest-log text."""
    value = value or ""
    value = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", " ", value)
    value = re.sub(r"\$[Nn]", "$n", value)
    value = re.sub(r"\$[Rr]", "$r", value)
    value = re.sub(r"\$[Cc]", "$c", value)
    value = re.sub(r"\$[Bb]", " ", value)
    value = re.sub(r"\$[Gg]([^:;]+):([^;]+);", r"\1/\2", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value.casefold()


def joined_signature(values) -> str:
    return ",".join(sorted({str(value) for value in values}))


def validate_turtle_overrides(conn: sqlite3.Connection) -> None:
    """Reject Turtle builds that lose hand-maintained compatibility rows."""
    keg_objective = conn.execute(
        """SELECT 1 FROM quest_target
           WHERE quest_id = 41682 AND phase = 'obj'
             AND target_kind = 'O' AND target_id = 2020173"""
    ).fetchone()
    if not keg_objective:
        raise RuntimeError(
            "Turtle override regression: quest 41682 is missing object objective 2020173"
        )

    geshgan_source = conn.execute(
        """SELECT chance FROM item_source
           WHERE item_id = 41783 AND source_kind = 'U' AND source_id = 62217"""
    ).fetchone()
    if not geshgan_source or abs(float(geshgan_source[0]) - 100.0) > 1e-9:
        actual = geshgan_source[0] if geshgan_source else "missing"
        raise RuntimeError(
            "Turtle override regression: item 41783 must use unit 62217 at 100% "
            f"(found {actual})"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path, required=True, help="pfQuest source directory")
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "data" / "pfquest-turtle.sqlite")
    parser.add_argument("--turtle-source", type=pathlib.Path, help="optional pfQuest-turtle overlay source")
    parser.add_argument(
        "--locales",
        default="enUS",
        help="comma-separated locales to package (default: enUS)",
    )
    args = parser.parse_args()

    supported_locales = {"deDE", "enUS", "esES", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}
    locales = [locale.strip() for locale in args.locales.split(",") if locale.strip()]
    if not locales or any(locale not in supported_locales for locale in locales):
        parser.error("--locales must contain supported comma-separated locale names")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = args.output.parent / ".staging"
    staging.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "lua", str(ROOT / "tools" / "export_quests.lua"), str(args.source), str(staging),
        str(args.turtle_source or ""), ",".join(locales)
    ], check=True)

    if args.output.exists():
        args.output.unlink()
    conn = sqlite3.connect(args.output)
    conn.executescript("""
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        CREATE TABLE quest_text (
          locale TEXT NOT NULL,
          id INTEGER NOT NULL,
          title TEXT NOT NULL,
          objective TEXT NOT NULL,
          description TEXT NOT NULL,
          level TEXT NOT NULL,
          min_level TEXT NOT NULL,
          PRIMARY KEY (locale, id)
        );
        CREATE INDEX quest_text_title_idx ON quest_text(locale, title);
        CREATE TABLE quest_disambiguation (
          locale TEXT NOT NULL,
          title_key TEXT NOT NULL,
          quest_id INTEGER NOT NULL,
          objective_key TEXT NOT NULL,
          description_key TEXT NOT NULL,
          objective_targets TEXT NOT NULL,
          prerequisites TEXT NOT NULL,
          level TEXT NOT NULL,
          race_mask TEXT NOT NULL,
          class_mask TEXT NOT NULL,
          resolution_class TEXT NOT NULL,
          PRIMARY KEY (locale, quest_id)
        );
        CREATE INDEX quest_disambiguation_title_idx
          ON quest_disambiguation(locale, title_key);
        CREATE TABLE entity_text (
          locale TEXT NOT NULL,
          target_kind TEXT NOT NULL,
          target_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          PRIMARY KEY (locale, target_kind, target_id)
        );
        CREATE TABLE entity_meta (
          target_kind TEXT NOT NULL,
          target_id INTEGER NOT NULL,
          level TEXT NOT NULL,
          faction TEXT NOT NULL,
          rank TEXT NOT NULL,
          PRIMARY KEY (target_kind, target_id)
        );
        CREATE TABLE object_skill (
          object_id INTEGER PRIMARY KEY,
          required_skill TEXT NOT NULL,
          profession TEXT NOT NULL
        );
        CREATE TABLE meta_relation (
          relation TEXT NOT NULL,
          target_kind TEXT NOT NULL,
          target_id INTEGER NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (relation, target_kind, target_id)
        );
        CREATE INDEX meta_relation_lookup_idx ON meta_relation(relation, value);
        CREATE TABLE item_text (
          locale TEXT NOT NULL,
          item_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          PRIMARY KEY (locale, item_id)
        );
        CREATE TABLE item_source (
          item_id INTEGER NOT NULL,
          source_kind TEXT NOT NULL,
          source_id INTEGER NOT NULL,
          chance TEXT NOT NULL,
          PRIMARY KEY (item_id, source_kind, source_id)
        );
        CREATE INDEX item_source_item_idx ON item_source(item_id);
        CREATE INDEX item_source_source_idx ON item_source(source_kind, source_id);
        CREATE TABLE refloot_source (
          reference_id INTEGER NOT NULL,
          source_kind TEXT NOT NULL,
          source_id INTEGER NOT NULL,
          PRIMARY KEY (reference_id, source_kind, source_id)
        );
        CREATE INDEX refloot_source_reference_idx ON refloot_source(reference_id);
        CREATE INDEX refloot_source_target_idx ON refloot_source(source_kind, source_id, reference_id);
        CREATE TABLE zone_text (
          locale TEXT NOT NULL,
          zone_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          PRIMARY KEY (locale, zone_id)
        );
        CREATE TABLE zone_data (
          zone_id INTEGER PRIMARY KEY,
          map_id INTEGER NOT NULL,
          x TEXT NOT NULL,
          y TEXT NOT NULL
        );
        CREATE TABLE areatrigger_spawn (
          trigger_id INTEGER NOT NULL,
          x TEXT NOT NULL,
          y TEXT NOT NULL,
          zone_id INTEGER NOT NULL
        );
        CREATE INDEX areatrigger_spawn_trigger_idx ON areatrigger_spawn(trigger_id);
        CREATE TABLE quest_meta (
          quest_id INTEGER PRIMARY KEY,
          level TEXT NOT NULL,
          min_level TEXT NOT NULL,
          race_mask TEXT NOT NULL,
          class_mask TEXT NOT NULL,
          skill TEXT NOT NULL,
          event TEXT NOT NULL
        );
        CREATE TABLE quest_prerequisite (
          quest_id INTEGER NOT NULL,
          prerequisite_id INTEGER NOT NULL,
          PRIMARY KEY (quest_id, prerequisite_id)
        );
        CREATE INDEX quest_prerequisite_quest_idx ON quest_prerequisite(quest_id);
        CREATE TABLE item_requirement (
          item_id INTEGER NOT NULL,
          source_kind TEXT NOT NULL,
          source_id INTEGER NOT NULL,
          spell_id INTEGER NOT NULL,
          PRIMARY KEY (item_id, source_kind, source_id, spell_id)
        );
        CREATE INDEX item_requirement_item_idx ON item_requirement(item_id);
        CREATE TABLE quest_target (
          quest_id INTEGER NOT NULL,
          phase TEXT NOT NULL,
          target_kind TEXT NOT NULL,
          target_id INTEGER NOT NULL,
          PRIMARY KEY (quest_id, phase, target_kind, target_id)
        );
        CREATE INDEX quest_target_quest_idx ON quest_target(quest_id);
        CREATE INDEX quest_target_phase_idx ON quest_target(phase, target_kind, target_id);
        CREATE TABLE spawn (
          target_kind TEXT NOT NULL,
          target_id INTEGER NOT NULL,
          x TEXT NOT NULL,
          y TEXT NOT NULL,
          zone_id INTEGER NOT NULL,
          respawn TEXT NOT NULL
        );
        CREATE INDEX spawn_target_idx ON spawn(target_kind, target_id);
        CREATE INDEX spawn_coord_idx ON spawn(target_kind, zone_id, x, y, target_id);
    """)

    def records(name: str):
        for record in (staging / name).read_text(encoding="utf-8").split(ROW):
            if record:
                yield record.split(SEP)

    text_rows = []
    for fields in records("quest_text.tsv"):
        if len(fields) != 7:
            raise ValueError(f"invalid quest text row: {fields[:2]!r}")
        text_rows.append((fields[0], int(fields[1]), *fields[2:]))
    conn.executemany("INSERT INTO quest_text VALUES (?, ?, ?, ?, ?, ?, ?)", text_rows)

    entity_rows = []
    for fields in records("entity_text.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid entity text row: {fields[:3]!r}")
        entity_rows.append((fields[0], fields[1], int(fields[2]), fields[3]))
    conn.executemany("INSERT INTO entity_text VALUES (?, ?, ?, ?)", entity_rows)

    entity_meta_rows = []
    for fields in records("entity_meta.tsv"):
        if len(fields) != 5:
            raise ValueError(f"invalid entity metadata row: {fields[:2]!r}")
        entity_meta_rows.append((fields[0], int(fields[1]), fields[2], fields[3], fields[4]))
    conn.executemany("INSERT INTO entity_meta VALUES (?, ?, ?, ?, ?)", entity_meta_rows)

    object_skill_rows = []
    for fields in records("object_skill.tsv"):
        if len(fields) != 3:
            raise ValueError(f"invalid object skill row: {fields[:2]!r}")
        object_skill_rows.append((int(fields[0]), fields[1], fields[2]))
    conn.executemany("INSERT OR REPLACE INTO object_skill VALUES (?, ?, ?)", object_skill_rows)

    meta_rows = []
    for fields in records("meta_relation.tsv"):
        if len(fields) != 4: raise ValueError(f"invalid meta relation row: {fields[:2]!r}")
        meta_rows.append((fields[0], fields[1], int(fields[2]), fields[3]))
    conn.executemany("INSERT OR REPLACE INTO meta_relation VALUES (?, ?, ?, ?)", meta_rows)

    item_rows = []
    for fields in records("item_text.tsv"):
        if len(fields) != 3:
            raise ValueError(f"invalid item text row: {fields[:2]!r}")
        item_rows.append((fields[0], int(fields[1]), fields[2]))
    conn.executemany("INSERT INTO item_text VALUES (?, ?, ?)", item_rows)

    item_source_rows = []
    for fields in records("item_source.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid item source row: {fields[:2]!r}")
        item_source_rows.append((int(fields[0]), fields[1], int(fields[2]), fields[3]))
    conn.executemany("INSERT OR REPLACE INTO item_source VALUES (?, ?, ?, ?)", item_source_rows)

    refloot_rows = []
    for fields in records("refloot_source.tsv"):
        if len(fields) != 3:
            raise ValueError(f"invalid refloot row: {fields[:2]!r}")
        refloot_rows.append((int(fields[0]), fields[1], int(fields[2])))
    conn.executemany("INSERT OR IGNORE INTO refloot_source VALUES (?, ?, ?)", refloot_rows)

    zone_text_rows = []
    for fields in records("zone_text.tsv"):
        if len(fields) != 3:
            raise ValueError(f"invalid zone text row: {fields[:2]!r}")
        zone_text_rows.append((fields[0], int(fields[1]), fields[2]))
    conn.executemany("INSERT INTO zone_text VALUES (?, ?, ?)", zone_text_rows)

    zone_data_rows = []
    for fields in records("zone_data.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid zone data row: {fields[:2]!r}")
        zone_data_rows.append((int(fields[0]), int(fields[1]), fields[2], fields[3]))
    conn.executemany("INSERT INTO zone_data VALUES (?, ?, ?, ?)", zone_data_rows)

    trigger_rows = []
    for fields in records("areatrigger_spawn.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid areatrigger row: {fields[:2]!r}")
        trigger_rows.append((int(fields[0]), fields[1], fields[2], int(fields[3])))
    conn.executemany("INSERT INTO areatrigger_spawn VALUES (?, ?, ?, ?)", trigger_rows)

    quest_meta_rows = []
    for fields in records("quest_meta.tsv"):
        if len(fields) != 7:
            raise ValueError(f"invalid quest meta row: {fields[:2]!r}")
        quest_meta_rows.append((int(fields[0]), *fields[1:]))
    conn.executemany("INSERT INTO quest_meta VALUES (?, ?, ?, ?, ?, ?, ?)", quest_meta_rows)

    prerequisite_rows = []
    for fields in records("quest_prerequisite.tsv"):
        if len(fields) != 2:
            raise ValueError(f"invalid prerequisite row: {fields[:2]!r}")
        prerequisite_rows.append((int(fields[0]), int(fields[1])))
    conn.executemany("INSERT OR IGNORE INTO quest_prerequisite VALUES (?, ?)", prerequisite_rows)

    item_requirement_rows = []
    for fields in records("item_requirement.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid item requirement row: {fields[:2]!r}")
        item_requirement_rows.append((int(fields[0]), fields[1], int(fields[2]), int(fields[3])))
    conn.executemany("INSERT OR IGNORE INTO item_requirement VALUES (?, ?, ?, ?)", item_requirement_rows)

    target_rows = []
    for fields in records("quest_target.tsv"):
        if len(fields) != 4:
            raise ValueError(f"invalid quest target row: {fields[:2]!r}")
        target_rows.append((int(fields[0]), *fields[1:3], int(fields[3])))
    conn.executemany("INSERT OR IGNORE INTO quest_target VALUES (?, ?, ?, ?)", target_rows)

    quest_meta_by_id = {row[0]: row for row in quest_meta_rows}
    prerequisites_by_id = collections.defaultdict(list)
    for quest_id, prerequisite_id in prerequisite_rows:
        prerequisites_by_id[quest_id].append(prerequisite_id)
    targets_by_id = collections.defaultdict(list)
    for quest_id, phase, target_kind, target_id in target_rows:
        if phase == "obj":
            targets_by_id[quest_id].append(f"{target_kind}:{target_id}")

    by_title = collections.defaultdict(list)
    for locale, quest_id, title, objective, description, level, _ in text_rows:
        title_key = normalize_quest_text(title)
        by_title[(locale, title_key)].append({
            "quest_id": quest_id,
            "objective_key": normalize_quest_text(objective),
            "description_key": normalize_quest_text(description),
            "objective_targets": joined_signature(targets_by_id[quest_id]),
            "prerequisites": joined_signature(prerequisites_by_id[quest_id]),
            "level": str(level or ""),
            "race_mask": str(quest_meta_by_id.get(quest_id, (None, "", "", "", ""))[3] or ""),
            "class_mask": str(quest_meta_by_id.get(quest_id, (None, "", "", "", ""))[4] or ""),
        })

    disambiguation_rows = []
    resolution_counts = collections.Counter()
    unresolved_groups = []
    for (locale, title_key), candidates in sorted(by_title.items()):
        if len(candidates) < 2:
            continue

        text_keys = [
            (candidate["objective_key"], candidate["description_key"])
            for candidate in candidates
        ]
        structural_keys = [
            text_keys[index] + (
                candidate["objective_targets"], candidate["prerequisites"],
            )
            for index, candidate in enumerate(candidates)
        ]
        conditional_keys = [
            structural_keys[index] + (
                candidate["level"], candidate["race_mask"], candidate["class_mask"],
            )
            for index, candidate in enumerate(candidates)
        ]
        text_complete = all(any(key) for key in text_keys)
        structural_complete = all(any(key) for key in structural_keys)
        if text_complete and len(set(text_keys)) == len(candidates):
            resolution_class = "TEXT_UNIQUE"
        elif structural_complete and len(set(structural_keys)) == len(candidates):
            resolution_class = "STRUCTURAL_UNIQUE"
        elif len(set(conditional_keys)) == len(candidates):
            resolution_class = "CONDITIONAL"
        elif len(set(conditional_keys)) > 1:
            resolution_class = "PARTIAL"
        else:
            resolution_class = "UNRESOLVABLE"

        resolution_counts[resolution_class] += 1
        if resolution_class in {"PARTIAL", "UNRESOLVABLE"}:
            unresolved_groups.append((locale, title_key, resolution_class, len(candidates)))
        for candidate in candidates:
            disambiguation_rows.append((
                locale, title_key, candidate["quest_id"], candidate["objective_key"],
                candidate["description_key"], candidate["objective_targets"],
                candidate["prerequisites"], candidate["level"], candidate["race_mask"],
                candidate["class_mask"], resolution_class,
            ))
    conn.executemany(
        "INSERT INTO quest_disambiguation VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        disambiguation_rows,
    )

    spawn_rows = []
    for fields in records("spawn.tsv"):
        if len(fields) != 6:
            raise ValueError(f"invalid spawn row: {fields[:2]!r}")
        spawn_rows.append((fields[0], int(fields[1]), *fields[2:4], int(fields[4]), fields[5]))
    conn.executemany("INSERT INTO spawn VALUES (?, ?, ?, ?, ?, ?)", spawn_rows)
    if args.turtle_source:
        validate_turtle_overrides(conn)
    conn.commit()
    conn.execute("VACUUM")
    conn.close()
    for path in staging.iterdir():
        path.unlink()
    staging.rmdir()
    print(
        f"wrote {len(text_rows)} quest text rows, {len(entity_rows)} entity text rows, {len(entity_meta_rows)} entity metadata rows, {len(object_skill_rows)} object skill rows, {len(item_rows)} item text rows, "
        f"{len(item_source_rows)} item-source rows, {len(refloot_rows)} reference-loot rows, "
        f"{len(zone_text_rows)} zone text rows, {len(zone_data_rows)} zone rows, {len(trigger_rows)} trigger rows, "
        f"{len(item_requirement_rows)} item-requirement rows, {len(quest_meta_rows)} quest metadata rows, "
        f"and {len(prerequisite_rows)} prerequisite rows, "
        f"{len(target_rows)} target rows, and {len(spawn_rows)} spawn rows "
        f"to {args.output} ({args.output.stat().st_size:,} bytes)"
    )
    print(
        "same-title groups: "
        + ", ".join(f"{key}={resolution_counts[key]}" for key in (
            "TEXT_UNIQUE", "STRUCTURAL_UNIQUE", "CONDITIONAL", "PARTIAL", "UNRESOLVABLE"
        ))
    )
    for locale, title_key, resolution_class, count in unresolved_groups[:25]:
        print(f"  {resolution_class}: {locale} {title_key!r} ({count} candidates)")


if __name__ == "__main__":
    main()
