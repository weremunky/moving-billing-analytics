"""Small helpers shared by the scripts."""
import csv
import sqlite3


def split_statements(sql):
    """Split a .sql file into complete statements (handles ; inside strings)."""
    stmts, buf = [], ""
    for line in sql.splitlines(keepends=True):
        buf += line
        if sqlite3.complete_statement(buf):
            body = "\n".join(l for l in buf.splitlines() if not l.strip().startswith("--")).strip()
            if body:
                stmts.append(buf.strip())
            buf = ""
    return stmts


def run(con, stmt):
    cur = con.execute(stmt)
    cols = [d[0] for d in cur.description] if cur.description else []
    return cols, cur.fetchall()


def write_csv(path, cols, rows):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)


def to_markdown(cols, rows, limit=15):
    if not cols:
        return ""
    fmt = lambda v: "" if v is None else (f"{v:,.2f}" if isinstance(v, float) else str(v))
    out = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    out += ["| " + " | ".join(fmt(v) for v in r) + " |" for r in rows[:limit]]
    if len(rows) > limit:
        out.append(f"\n_...{len(rows) - limit} more rows in the CSV_")
    return "\n".join(out)
