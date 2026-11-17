"""
Run all 10 business-question queries and export results.

Writes to output/:
  results.md                   every query result as a readable table
  NN_<query_name>[_K].csv      each result set as CSV (_K when a file has several queries)
  tableau_job_financials.csv   one row per job  -> main Tableau data source
  tableau_data_quality.csv     one row per issue -> Tableau data-quality panel
  tableau_monthly.csv          monthly report view

Usage:  python scripts/run_report.py moving.db
"""
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sqlutil import run, split_statements, to_markdown, write_csv

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "output"


def main(db_path):
    OUT.mkdir(exist_ok=True)
    con = sqlite3.connect(db_path)
    md = [f"# Query results\n\nDatabase: `{Path(db_path).name}`\n"]
    for qfile in sorted((ROOT / "sql/queries").glob("*.sql")):
        sql = qfile.read_text()
        title = next(l for l in sql.splitlines() if l.startswith("-- Q")).lstrip("- ").strip()
        md.append(f"\n## {title}\n")
        stmts = split_statements(sql)
        for k, stmt in enumerate(stmts, 1):
            cols, rows = run(con, stmt)
            suffix = f"_{k}" if len(stmts) > 1 else ""
            write_csv(OUT / f"{qfile.stem}{suffix}.csv", cols, rows)
            md.append(to_markdown(cols, rows) or "_(no rows)_")
            md.append("")
        print(f"  ran {qfile.name}")

    for view, name in [("v_job_financials", "tableau_job_financials"),
                       ("v_data_quality", "tableau_data_quality"),
                       ("v_monthly_report", "tableau_monthly")]:
        cols, rows = run(con, f"SELECT * FROM {view}")
        write_csv(OUT / f"{name}.csv", cols, rows)
    (OUT / "results.md").write_text("\n".join(md))
    print(f"Wrote results to {OUT}/")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "moving.db")
