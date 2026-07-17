#!/usr/bin/env python3
"""Generate WorkloadApp/Resources/ExerciseCatalog.json from the
hasaneyldrm/exercises-dataset repo (https://github.com/hasaneyldrm/exercises-dataset).

Only the MIT-licensed data fields are used. The Gym visual media
(images/, videos/) is NOT licensed for redistribution and is never copied.

Usage:
    python3 scripts/generate_exercise_catalog.py /path/to/exercises-dataset

Output: WorkloadApp/Resources/ExerciseCatalog.json
  - instructions kept in en + zh only (app is en + zh-Hans localized)
  - dataset target/muscle mapped onto the app's MuscleGroup rawValues (Enums.swift)
  - ExerciseCategory derived per record (drives input mode: weightReps / repsOnly / ...)
"""

import json
import re
import sys
from pathlib import Path

# Dataset `target` -> app MuscleGroup rawValue (Enums.swift, Phase 22 taxonomy).
# Coarse cases are used where the dataset target is not anatomically specific.
TARGET_TO_MUSCLE = {
    "abs": "rectusAbdominis",
    "pectorals": "chest",
    "biceps": "biceps",
    "glutes": "glutes",
    "delts": "shoulders",
    "triceps": "triceps",
    "upper back": "back",
    "lats": "lats",
    "calves": "calves",
    "quads": "quads",
    "forearms": "forearms",
    "cardiovascular system": "fullBody",
    "hamstrings": "hamstrings",
    "spine": "erectors",
    "traps": "trapsUpper",
    "adductors": "adductors",
    "serratus anterior": "chest",
    "abductors": "glutes",
    "levator scapulae": "trapsUpper",
}

# Name-based refinements applied after the coarse target mapping.
# (pattern, required coarse mapping or None, refined MuscleGroup rawValue)
NAME_REFINEMENTS = [
    (re.compile(r"\bincline\b"), "chest", "pecsUpper"),
    (re.compile(r"\bdecline\b"), "chest", "pecsLower"),
    (re.compile(r"\blateral raise\b"), "shoulders", "lateralDelts"),
    (re.compile(r"\bfront raise\b"), "shoulders", "anteriorDelts"),
    (re.compile(r"rear (delt|lateral)|reverse fl"), "shoulders", "posteriorDelts"),
    (re.compile(r"\boblique|side bend|russian twist|side crunch"), "rectusAbdominis", "obliques"),
]

COMPOUND_PATTERNS = re.compile(
    r"squat|deadlift|press|row(?!er)|pull-?up|chin-?up|pulldown|pull down|lunge|"
    r"clean|snatch|thruster|\bdip\b|hip thrust|good morning|step-?up|carry|"
    r"swing|jerk|muscle up|burpee|sled|farmer"
)
PLYO_PATTERNS = re.compile(r"jump|hop|bound|plyo|explosive")

TITLE_FIXUPS = {
    "ez": "EZ",
    "v.": "V.",
    "v-up": "V-Up",
    "iv": "IV",
    "ii": "II",
    "iii": "III",
    "nfl": "NFL",
}


def title_case(name: str) -> str:
    def cap_token(tok: str) -> str:
        if tok.lower() in TITLE_FIXUPS:
            return TITLE_FIXUPS[tok.lower()]
        # capitalize each hyphen-separated part: "pull-up" -> "Pull-Up"
        return "-".join(p[:1].upper() + p[1:] if p else p for p in tok.split("-"))

    return " ".join(cap_token(t) for t in name.split(" "))


def muscle_group(rec: dict) -> str:
    base = TARGET_TO_MUSCLE.get(rec["target"], "fullBody")
    lname = rec["name"].lower()
    for pattern, requires, refined in NAME_REFINEMENTS:
        if (requires is None or base == requires) and pattern.search(lname):
            return refined
    return base


def category(rec: dict) -> str:
    lname = rec["name"].lower()
    if rec["body_part"] == "cardio" or rec["target"] == "cardiovascular system":
        return "cardio"
    if rec["equipment"] in ("body weight", "assisted"):
        if PLYO_PATTERNS.search(lname):
            return "plyometric"
        return "bodyweight"
    if COMPOUND_PATTERNS.search(lname):
        return "compound"
    return "isolation"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]) / "data" / "exercises.json"
    out = Path(__file__).resolve().parent.parent / "WorkloadApp" / "Resources" / "ExerciseCatalog.json"

    records = json.loads(src.read_text())
    catalog = []
    for rec in records:
        catalog.append(
            {
                "id": rec["id"],
                "name": title_case(rec["name"]),
                "bodyPart": rec["body_part"],
                "equipment": rec["equipment"],
                "target": rec["target"],
                "muscleGroup": muscle_group(rec),
                "category": category(rec),
                "secondaryMuscles": rec["secondary_muscles"],
                "steps": {
                    "en": rec["instruction_steps"]["en"],
                    "zh": rec["instruction_steps"]["zh"],
                },
            }
        )

    # Stable order for reproducible diffs
    catalog.sort(key=lambda r: r["id"])
    out.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")))
    sizes = {}
    for field in ("muscleGroup", "category", "equipment", "bodyPart"):
        vals = {}
        for r in catalog:
            vals[r[field]] = vals.get(r[field], 0) + 1
        sizes[field] = vals
    print(f"wrote {len(catalog)} exercises -> {out} ({out.stat().st_size / 1e6:.2f} MB)")
    for field, vals in sizes.items():
        print(field, dict(sorted(vals.items(), key=lambda kv: -kv[1])))


if __name__ == "__main__":
    main()
