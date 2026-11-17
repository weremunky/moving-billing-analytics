"""
Anonymize a raw Excel/CSV export before it goes anywhere public.

- Replaces each distinct value in an identifying column with a stable ID
  (e.g. 'Jane Smith' -> 'C001'). The mapping is saved to a PRIVATE file so
  you can re-run it on next month's export and keep the same IDs.
- Drops columns you list (addresses, phone numbers, emails, notes).

Usage example:
  python scripts/anonymize.py data/raw/jobs_export.csv data/clean/jobs.csv \
      --map client_name:C:private/client_map.csv \
      --map crew_member:E:private/employee_map.csv \
      --drop address,phone,email,notes

Keep the private/ folder OUT of git (it's in .gitignore).
"""
import argparse
import csv
from pathlib import Path


def load_map(path):
    if not path.exists():
        return {}
    with open(path, newline="") as f:
        return {r["original"]: r["id"] for r in csv.DictReader(f)}


def save_map(path, mapping):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["original", "id"])
        w.writerows(sorted(mapping.items(), key=lambda kv: kv[1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--map", action="append", default=[],
                    help="column:PREFIX:mapfile  (repeatable)")
    ap.add_argument("--drop", default="", help="comma-separated columns to remove")
    a = ap.parse_args()

    drops = {c.strip().lower() for c in a.drop.split(",") if c.strip()}
    specs = []
    for m in a.map:
        col, prefix, mapfile = m.split(":", 2)
        mp = Path(mapfile)
        specs.append((col.strip().lower(), prefix, mp, load_map(mp)))

    with open(a.input, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        reader.fieldnames = [h.strip().lower() for h in reader.fieldnames]
        rows = list(reader)

    for col, prefix, _, mapping in specs:
        width = 3 if prefix.upper().startswith("C") else 2
        for r in rows:
            key = (r.get(col) or "").strip()
            if not key:
                continue
            norm = " ".join(key.lower().split())   # 'Jane  Smith ' == 'jane smith'
            if norm not in mapping:
                mapping[norm] = f"{prefix}{len(mapping) + 1:0{width}d}"
            r[col] = mapping[norm]

    keep = [c for c in reader.fieldnames if c not in drops]
    Path(a.output).parent.mkdir(parents=True, exist_ok=True)
    with open(a.output, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keep, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    for col, _, mp, mapping in specs:
        save_map(mp, mapping)
        print(f"  {col}: {len(mapping)} distinct values -> {mp} (PRIVATE)")
    print(f"Wrote {a.output} ({len(rows)} rows, dropped: {sorted(drops & set(reader.fieldnames)) or 'none'})")


if __name__ == "__main__":
    main()
