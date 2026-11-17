# Moving Billing & Profitability Analytics
A SQL database and analysis toolkit for a moving company. It turns spreadsheet billing (jobs, crew hours, job costs) into a relational database, catches billing errors before invoices go out, and shows which jobs actually make money per crew hour. Built around my real work as a Business Analyst / Project Coordinator, with Tableau-ready exports for a monthly dashboard.
---
## What This Does
At work, I track billing for 12-25 moving jobs a week across three Excel sheets: jobs, crew hours, and job costs (truck rental, equipment). That setup let mistakes slip through. I once caught a truck rental entered twice on a multi-day job, and there was no easy way to check how often that happens.

This project turns those sheets into a proper SQL database and answers the questions the business actually cares about:

* What's the real margin on each job after labor, truck and equipment costs?
* Are small 1-hour jobs or big multi-day moves more profitable per crew hour?
* Which jobs have billing errors that should be fixed before the invoice goes out?

Client and payroll data stays private. The data in this repo is **synthetic**, but it's calibrated to public 2025-2026 industry benchmarks: San Diego hourly mover rates with a 2-hour minimum, California wages, truck rental prices, long-distance pricing, and national moving seasonality. That way it behaves like a real operation. It also includes planted errors to prove the checks catch them. Sources are listed at the bottom.
---
## Key Features

* 7-table SQL schema: jobs, clients, employees, pay rates, crew hours, job costs, payments
* 10 business-question queries using CTEs, window functions (LAG, RANK, SUM OVER) and date-range joins
* True labor cost: every shift is costed at the pay rate that was active that day, so a raise doesn't change the cost of old jobs
* Pre-billing data-quality check: 8 rules that flag duplicate charges, jobs with no hours logged, billed-vs-payroll mismatches and more
* California overtime: daily (over 8 hrs) and weekly (over 40 hrs) overtime per employee
* Excel-friendly loader: accepts dates like 10/3/2026 and amounts like $1,250.00, and rejects bad rows with the file name and line number
* Anonymizer: replaces client and employee names with stable IDs (C001, E01) and drops personal columns
* Tableau-ready CSV exports for the dashboard

---
## Setup & Installation
You'll need Python 3.8+. All scripts use the standard library only.

That's it. No pip packages, no database server, and no external APIs or paid services needed.
---
## Universal Usage & Custom Data
You can use this for any small service business that tracks jobs, crew hours and costs (moving, cleaning, landscaping, contracting). Just swap in your own CSVs.

Put these files in one folder:

    clients.csv     client_id, client_type, city
    employees.csv   employee_id, role
    pay_rates.csv   employee_id, rate, start_date, end_date
    jobs.csv        job_id, client_id, job_date, job_type, billed_hours, amount_billed, status
    crew_hours.csv  job_id, employee_id, work_date, hours
    job_costs.csv   job_id, cost_type, cost_date, amount
    payments.csv    job_id, paid_date, amount   (optional)

Then build the database from that folder:

```bash
python3 scripts/build_db.py path/to/your_folder my_company.db
```

To anonymize a raw export first:

```bash
python3 scripts/anonymize.py raw_jobs.csv jobs.csv --map "client name:C:private/client_map.csv" --drop address,phone
```

The private map file keeps IDs the same from month to month. It's in `.gitignore`, so it never gets committed.
---
## How to Run
Generate the sample data, build the database, then run the checks and the report:

```bash
python3 scripts/generate_sample_data.py
python3 scripts/build_db.py data/sample moving.db
python3 scripts/run_checks.py moving.db
python3 scripts/run_report.py moving.db
```

The scripts will:

* Load every CSV into SQLite with type checks and foreign keys
* Print a data-quality report listing every issue found before billing
* Run all 10 queries and save the results to `output/` (a readable `results.md` plus one CSV per query)
* Export the three CSVs the Tableau dashboard uses

---
## Understanding the Results
Results on the synthetic data: 938 jobs over 12 months (November 2025 - October 2026). "Margin" here is contribution margin: revenue minus crew wages, truck, equipment and materials, before overhead like insurance, workers' comp and marketing.

* Small jobs earn the most per crew hour by far: about $93 of margin per crew hour, vs. $36 for standard local moves. The reason is the 2-hour minimum. A 1-hour job is still billed for 2 hours
* Long-distance moves come second at about $52 per crew hour, because of flat pricing
* The check caught all 3 planted duplicate truck rentals, plus 4 paid jobs ($14.4K billed) with no crew hours logged, so their labor cost was invisible
* 7 jobs had billed hours below payroll hours: about 24 crew-hours worked but never billed
* May-August brought in 42% of all jobs, and the weeks ranged from 5 jobs (the holidays) to 31 (summer)
* A third of jobs fall in the last week of the month, when leases turn over
* Repeat customers are only 14% of clients but bring in 34% of revenue
* About 7.7% of crew hours were overtime under California's daily/weekly rules

What I'd recommend based on this:

* Market small jobs and use them to fill gaps in the crew schedule. With the 2-hour minimum, they're the most profitable work per hour
* Add crew capacity (temp movers) for May-August and month-end, instead of turning work away
* Run the data-quality check before every invoice batch, and check billed hours against payroll so every hour worked gets billed

---
## What I Learned
This was my first project designing a database from scratch around real business data, and:

* I learned to decide what one row in each table means (one row per employee, per job, per day) before writing any queries
* I learned about the join fan-out problem: joining hours and costs to jobs at the same time multiplies the rows and inflates revenue. I avoid it by totaling each one per job in its own CTE first
* I left the unique constraint off the costs table on purpose, so duplicate charges load and get counted instead of being silently rejected
* My first duplicate check was too noisy. It flagged every normal multi-day truck rental, so I changed it to compare truck entries against the number of days the crew actually worked

---
## Next Steps & Improvements
Some ideas for future versions:

* Move to PostgreSQL
* Pull purchase orders straight from Salesforce instead of exporting sheets
* Run the data-quality check automatically before every billing run
* Include the overtime premium (1.5x) and payroll taxes in labor cost
* Publish the Tableau dashboard to Tableau Public

---
## Sources for the Sample Data Calibration

* Local mover rates and 2-hour minimum: [moveAdvisor](https://moveadvisor.com/move/cost-to-hire-movers-in-san-diego), [Swift Move SD](https://swift-move-sd.pages.dev/blog/how-much-does-a-local-move-cost-in-san-diego-2026/)
* Long-distance pricing (San Diego to Phoenix / Las Vegas / Bay Area): [Swift Move SD](https://swift-move-sd.pages.dev/blog/san-diego-to-phoenix-las-vegas-or-bay-area-the-long-distance-mover-comparison/)
* Mover wages: [BLS OEWS 53-7062](https://www.bls.gov/Oes/current/oes537062.htm); California minimum wage: [CalChamber](https://hrwatchdog.calchamber.com/2025/08/californias-2026-minimum-wage-increases-to-16-90-per-hour/)
* Seasonality and day of week: [moveBuddha](https://movebuddha.com/blog/peak-moving-season/), [HireAHelper](https://www.hireahelper.com/advice/when-is-peak-moving-season/)
* Truck rental prices: [SpareFoot](https://sparefoot.com/blog/moving-truck-rental-cost/)

---
Yan Angel, 2026
