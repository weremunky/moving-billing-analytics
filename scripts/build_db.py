"""
Build the SQLite database from a folder of CSVs.

Expected files (header row required; extra columns are ignored):
  clients.csv     client_id, client_type, city
  employees.csv   employee_id, role
  pay_rates.csv   employee_id, rate, start_date, end_date
  jobs.csv        job_id, client_id, job_date, job_type, billed_hours, amount_billed, status
  crew_hours.csv  job_id, employee_id, work_date, hours
  job_costs.csv   job_id, cost_type, cost_date, amount
  payments.csv    job_id, paid_date, amount            (optional)

Dates may be YYYY-MM-DD or Excel-style M/D/YYYY. Money may include $ and commas.
Text values are lower-cased and trimmed for the category columns.

Usage:  python scripts/build_db.py data/sample moving.db
"""
import csv
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLES = {
    "clients":    ["client_id", "client_type", "city"],
    "employees":  ["employee_id", "role"],
    "pay_rates":  ["employee_id", "rate", "start_date", "end_date"],
    "jobs":       ["job_id", "client_id", "job_date", "job_type", "billed_hours", "amount_billed", "status"],
    "crew_hours": ["job_id", "employee_id", "work_date", "hours"],
    "job_costs":  ["job_id", "cost_type", "cost_date", "amount"],
    "payments":   ["job_id", "paid_date", "amount"],
}
OPTIONAL = {"payments"}
DATE_COLS = {"start_date", "end_date", "job_date", "work_date", "cost_date", "paid_date"}
NUM_COLS = {"rate", "billed_hours", "amount_billed", "hours", "amount"}
LOWER_COLS = {"client_type", "job_type", "status", "cost_type", "role"}


def parse_date(v):
    v = v.strip()
    if not v:
        return None
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y", "%Y/%m/%d", "%m-%d-%Y"):
        try:
            return datetime.strptime(v, fmt).date().isoformat()
        except ValueError:
            pass
    raise ValueError(f"Unrecognized date: {v!r}")


def parse_num(v):
    v = v.strip().replace("$", "").replace(",", "")
    return float(v) if v else None


def clean(col, v):
    if v is None:
        return None
    if col in DATE_COLS:
        return parse_date(v)
    if col in NUM_COLS:
        return parse_num(v)
    v = v.strip()
    if col in LOWER_COLS:
        v = v.lower()
    return v or None


def main(data_dir, db_path):
    data_dir, db_path = Path(data_dir), Path(db_path)
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.execute("PRAGMA foreign_keys = ON")
    con.executescript((ROOT / "sql/schema.sql").read_text())

    for table, cols in TABLES.items():   # dict order = foreign-key-safe load order
        path = data_dir / f"{table}.csv"
        if not path.exists():
            if table in OPTIONAL:
                print(f"  {table:<11} skipped (no file; payment questions will be empty)")
                continue
            sys.exit(f"Missing required file: {path}")
        with open(path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            reader.fieldnames = [h.strip().lower() for h in reader.fieldnames]
            missing = [c for c in cols if c not in reader.fieldnames]
            if missing:
                sys.exit(f"{path.name} is missing columns: {missing}")
            rows = []
            for n, r in enumerate(reader, start=2):
                try:
                    rows.append([clean(c, r[c]) for c in cols])
                except ValueError as e:
                    sys.exit(f"{path.name} line {n}: {e}")
        try:
            con.executemany(
                f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})", rows)
        except sqlite3.IntegrityError as e:
            sys.exit(f"{path.name}: {e} (check IDs and allowed category values in sql/schema.sql)")
        print(f"  {table:<11} {len(rows):>6} rows")

    con.executescript((ROOT / "sql/views.sql").read_text())
    # create v_data_quality (the trailing summary SELECT in checks.sql is just ignored here)
    con.executescript((ROOT / "sql/checks.sql").read_text())
    con.commit()
    con.close()
    print(f"Built {db_path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "data/sample",
         sys.argv[2] if len(sys.argv) > 2 else "moving.db")
