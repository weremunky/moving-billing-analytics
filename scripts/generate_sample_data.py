"""
Generate a synthetic sample dataset for a San Diego moving company.

The data is calibrated to public 2025-2026 benchmarks so it
behaves like a real operation (sources listed in the README):

  - Local pricing: hourly crew rate (2 movers ~$130-170/hr), 2-hour minimum,
    billed in 15-minute increments
  - Long-distance (Phoenix, Las Vegas, Bay Area): flat price ~$2,600-7,500
  - Wages: movers $18-21/hr, drivers $21-24, leads $23-27 (CA minimum $16.90)
  - Seasonality: May-Aug ~43% of jobs; Monday busiest, Tuesday slowest;
    month-end (lease turnover) busier
  - Truck rental: $60-150/day plus $0.79-0.99/mile; one-way long-distance
    rentals priced separately

Planted errors (so the data-quality checks have something to find):
  3 duplicate truck rentals, 4 billed jobs with no hours, 6 under-billed jobs,
  1 double-entered shift.

Usage:  python scripts/generate_sample_data.py [out_dir]   (default: data/sample)
"""
import csv
import random
import sys
from datetime import date, timedelta
from pathlib import Path

random.seed(42)
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "data/sample")
OUT.mkdir(parents=True, exist_ok=True)

START, END = date(2025, 11, 1), date(2026, 10, 31)     # 12 full months

# Share of annual jobs by month (May-Aug = 43.5%)
MONTH_SHARE = {1: .065, 2: .065, 3: .075, 4: .080, 5: .100, 6: .115,
               7: .110, 8: .110, 9: .085, 10: .075, 11: .060, 12: .060}
# Day-of-week weights (Mon=0): Monday busiest, Tuesday slowest
DOW_WEIGHT = [1.40, 0.84, 0.91, 0.91, 1.00, 1.05, 0.80]
JOBS_PER_YEAR = 1000                                    # ~18/week, range ~12-25

LOCAL_CITIES = ["San Diego", "Chula Vista", "Oceanside", "Escondido", "Carlsbad",
                "El Cajon", "La Mesa", "Encinitas", "Santee", "Poway", "National City"]
LONG_DEST = [("Phoenix", 355, 2800, 5500), ("Las Vegas", 337, 2600, 5200),
             ("Los Angeles", 120, 1600, 3200), ("Bay Area", 500, 3800, 7500)]

# ---------------------------------------------------------------- employees
employees, pay_rates = [], []
roles = ["lead"] * 3 + ["driver"] * 3 + ["mover"] * 6
BASE = {"lead": (23, 27), "driver": (21, 24), "mover": (18, 21)}
for i, role in enumerate(roles, 1):
    eid = f"E{i:02d}"
    employees.append({"employee_id": eid, "role": role})
    rate = round(random.uniform(*BASE[role]) * 4) / 4
    if i in (2, 5, 7, 9):                               # mid-year raises
        pay_rates.append({"employee_id": eid, "rate": rate, "start_date": "2025-01-01", "end_date": "2026-06-30"})
        pay_rates.append({"employee_id": eid, "rate": rate + 1.5, "start_date": "2026-07-01", "end_date": ""})
    else:
        pay_rates.append({"employee_id": eid, "rate": rate, "start_date": "2025-01-01", "end_date": ""})
by_role = {r: [e for e in employees if e["role"] == r] for r in BASE}

# ---------------------------------------------------------------- clients
clients = []
for i in range(1, 801):
    clients.append({
        "client_id": f"C{i:03d}",
        "client_type": "commercial" if i <= 40 else "residential",
        "city": random.choices(LOCAL_CITIES, weights=[38, 9, 7, 7, 7, 6, 6, 5, 5, 5, 5])[0],
    })
commercial = clients[:40]
residential = clients[40:]
next_res = 0

# ---------------------------------------------------------------- job specs
# crew size, clock hours per day, number of days
JOB_TYPES = ["small", "local", "long-distance", "multi-day"]
JOB_MIX = [25, 55, 8, 12]
CREW_RATE = {2: (130, 170), 3: (175, 230), 4: (220, 300)}   # $/hr for the whole crew


def quarter(x):
    return max(0.25, round(x * 4) / 4)


def plan_job(jtype):
    if jtype == "small":
        return 2, [quarter(random.uniform(0.75, 1.75))]
    if jtype == "local":
        crew = random.choices([2, 3, 4], weights=[60, 32, 8])[0]
        return crew, [quarter(random.gauss(5.2 if crew == 2 else 6.0, 1.4))]
    if jtype == "multi-day":
        crew = random.choice([3, 4])
        return crew, [quarter(random.uniform(7, 9.5)) for _ in range(random.choice([2, 2, 3]))]
    crew = random.choice([2, 3])                         # long-distance
    return crew, [quarter(random.uniform(8, 10.5)) for _ in range(2)]


def pick_crew(size, dates, hours):
    """Pick a crew of people free on every date (max 10 hrs/day), lead first."""
    def free(e):
        return all(busy.get((e["employee_id"], d), 0) + h <= 10 for d, h in zip(dates, hours))
    leads = [e for e in by_role["lead"] + by_role["driver"] if free(e)]
    others = [e for e in employees if free(e)]
    if not leads or len(others) < size:
        return None
    lead = random.choice(leads)
    rest = random.sample([e for e in others if e is not lead], size - 1)
    return [lead] + rest


# ---------------------------------------------------------------- generate
jobs, crew_hours, job_costs, payments = [], [], [], []
busy = {}
job_n = 0
d = START
while d <= END:
    days_in_month = ((d.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)).day
    expected = JOBS_PER_YEAR * MONTH_SHARE[d.month] / days_in_month * DOW_WEIGHT[d.weekday()]
    if d.day >= 27 or d.day <= 2:
        expected *= 1.35                                 # month-end lease turnover
    for _ in range(max(0, round(random.gauss(expected, expected ** 0.5)))):
        jtype = random.choices(JOB_TYPES, weights=JOB_MIX)[0]
        crew_size, day_hours = plan_job(jtype)
        dates = [(d + timedelta(days=k)).isoformat() for k in range(len(day_hours))]
        crew = pick_crew(crew_size, dates, day_hours)
        if crew is None:
            continue                                     # fully booked that day
        job_n += 1
        jid = f"J{job_n:04d}"

        # client: commercial accounts book repeatedly; some residential repeat
        r = random.random()
        if r < 0.18:
            client = random.choice(commercial)["client_id"]
        elif r < 0.26 and next_res > 0:
            client = random.choice(residential[:next_res])["client_id"]
        else:
            client = residential[next_res % len(residential)]["client_id"]
            next_res += 1

        status = "paid" if d < END - timedelta(days=21) else random.choice(["billed", "billed", "paid", "completed"])
        if random.random() < 0.025:
            status = "cancelled"

        # hours + truck costs
        worked = 0.0
        if status != "cancelled":
            for wd, h in zip(dates, day_hours):
                for e in crew:
                    busy[(e["employee_id"], wd)] = busy.get((e["employee_id"], wd), 0) + h
                    crew_hours.append({"job_id": jid, "employee_id": e["employee_id"], "work_date": wd, "hours": h})
                    worked += h
            if jtype in ("local", "multi-day"):
                for wd in dates:
                    miles = random.randint(15, 70)
                    job_costs.append({"job_id": jid, "cost_type": "truck", "cost_date": wd,
                                      "amount": round(random.choice([69.99, 89.99, 109.99, 129.99])
                                                      + miles * random.choice([0.79, 0.89, 0.99]), 2)})
            if random.random() < (0.15 if jtype == "small" else 0.55):
                job_costs.append({"job_id": jid, "cost_type": "materials", "cost_date": dates[0],
                                  "amount": round(random.uniform(18, 140), 2)})
            if jtype in ("multi-day", "long-distance") and random.random() < 0.35:
                job_costs.append({"job_id": jid, "cost_type": "equipment", "cost_date": dates[0],
                                  "amount": random.choice([45, 65, 85])})

        # pricing
        if jtype == "long-distance":
            dest, miles, lo, hi = random.choices(LONG_DEST, weights=[35, 30, 20, 15])[0]
            amount = round(random.uniform(lo, hi) / 25) * 25
            billed_hours = ""                            # flat-rate job
            if status != "cancelled":
                one_way = round(random.uniform(1.1, 1.6) * miles + random.uniform(250, 450), 2)
                job_costs.append({"job_id": jid, "cost_type": "truck", "cost_date": dates[0], "amount": one_way})
        else:
            crew_rate = random.uniform(*CREW_RATE[crew_size])
            crew_rate = round(crew_rate / 5) * 5
            clock = sum(day_hours)
            billable_clock = max(clock, 2.0)              # 2-hour minimum
            amount = round(billable_clock * crew_rate, 2)
            billed_hours = worked
        if status == "cancelled":
            amount, billed_hours = 0, ""

        jobs.append({"job_id": jid, "client_id": client, "job_date": dates[0], "job_type": jtype,
                     "billed_hours": billed_hours, "amount_billed": amount, "status": status})

        if status == "paid":
            lag = random.choices([0, random.randint(1, 7), random.randint(8, 30), random.randint(31, 75)],
                                 weights=[55, 30, 12, 3])[0]
            payments.append({"job_id": jid, "paid_date": (date.fromisoformat(dates[-1]) + timedelta(days=lag)).isoformat(),
                             "amount": amount})
        elif status == "billed" and jtype == "long-distance":
            payments.append({"job_id": jid, "paid_date": dates[0], "amount": round(amount * 0.3, 2)})  # deposit
    d += timedelta(days=1)

# ---------------------------------------------------------------- planted errors
active = [j for j in jobs if j["status"] != "cancelled"]
for j in random.sample([j for j in active if j["job_type"] == "multi-day"], 3):
    truck = next(c for c in job_costs if c["job_id"] == j["job_id"] and c["cost_type"] == "truck")
    job_costs.append(dict(truck))                        # duplicate truck rental
for j in random.sample([j for j in active if j["status"] in ("billed", "paid") and j["job_type"] != "small"], 4):
    crew_hours[:] = [h for h in crew_hours if h["job_id"] != j["job_id"]]   # hours never logged
for j in random.sample([j for j in active if j["billed_hours"] != "" and j["billed_hours"] >= 10], 6):
    short = random.choice([2, 3, 4])
    j["billed_hours"] -= short                           # crew-hours left off invoice
dup = random.choice([h for h in crew_hours if h["hours"] >= 4])
crew_hours.append(dict(dup))                             # double-entered shift


def write(name, rows):
    with open(OUT / f"{name}.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


for name, rows in [("clients", clients), ("employees", employees), ("pay_rates", pay_rates),
                   ("jobs", jobs), ("crew_hours", crew_hours), ("job_costs", job_costs),
                   ("payments", payments)]:
    write(name, rows)
print(f"SYNTHETIC data written to {OUT}/: {len(jobs)} jobs, {len(crew_hours)} hour rows, "
      f"{len(job_costs)} cost rows, {len(payments)} payments")
