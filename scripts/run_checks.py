"""
Data-quality check. Run before each billing cycle.
Prints every flagged issue and exits with code 1 if anything is found,
so it can also be used in a scheduled job or a git hook.

Usage:  python scripts/run_checks.py moving.db
"""
import sqlite3
import sys

db = sys.argv[1] if len(sys.argv) > 1 else "moving.db"
con = sqlite3.connect(db)
rows = con.execute(
    "SELECT check_name, job_id, detail, amount_at_risk FROM v_data_quality "
    "ORDER BY check_name, job_id").fetchall()

if not rows:
    print("All checks passed. No issues found.")
    sys.exit(0)

current = None
for check, job, detail, amt in rows:
    if check != current:
        n = sum(1 for r in rows if r[0] == check)
        print(f"\n[{check}]  {n} issue(s)")
        current = check
    money = f"  (${amt:,.2f})" if amt else ""
    print(f"  {job or '-':<8} {detail}{money}")

total = sum(r[3] or 0 for r in rows)
print(f"\n{len(rows)} issue(s) found. Dollars directly flagged: ${total:,.2f}")
sys.exit(1)
