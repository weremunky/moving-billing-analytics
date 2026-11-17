-- =====================================================================
-- Moving Operations & Billing Analytics Database
-- Schema (SQLite 3.25+; also runs on PostgreSQL with minor type changes)
-- Dates are stored as ISO text: 'YYYY-MM-DD'
-- =====================================================================
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS job_costs;
DROP TABLE IF EXISTS crew_hours;
DROP TABLE IF EXISTS pay_rates;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS clients;

CREATE TABLE clients (
    client_id   TEXT PRIMARY KEY,                 -- anonymized, e.g. 'C001'
    client_type TEXT NOT NULL CHECK (client_type IN ('residential', 'commercial')),
    city        TEXT
);

CREATE TABLE jobs (
    job_id        TEXT PRIMARY KEY,
    client_id     TEXT NOT NULL REFERENCES clients(client_id),
    job_date      TEXT NOT NULL,                  -- first day of the job
    job_type      TEXT NOT NULL CHECK (job_type IN ('small', 'local', 'long-distance', 'multi-day')),
    billed_hours  NUMERIC,                        -- total crew-hours on the invoice (NULL if flat rate)
    amount_billed NUMERIC NOT NULL CHECK (amount_billed >= 0),
    status        TEXT NOT NULL CHECK (status IN ('scheduled', 'completed', 'billed', 'paid', 'cancelled'))
);

CREATE TABLE employees (
    employee_id TEXT PRIMARY KEY,                 -- anonymized, e.g. 'E01'
    role        TEXT NOT NULL                     -- e.g. 'mover', 'driver', 'lead'
);

-- One row per rate period. end_date NULL = current rate.
CREATE TABLE pay_rates (
    employee_id TEXT NOT NULL REFERENCES employees(employee_id),
    rate        NUMERIC NOT NULL CHECK (rate > 0),
    start_date  TEXT NOT NULL,
    end_date    TEXT,
    PRIMARY KEY (employee_id, start_date),
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- One row per employee per job per day. No primary key on purpose:
-- duplicate hour entries should load so the checks can flag them.
CREATE TABLE crew_hours (
    job_id      TEXT NOT NULL REFERENCES jobs(job_id),
    employee_id TEXT NOT NULL REFERENCES employees(employee_id),
    work_date   TEXT NOT NULL,
    hours       NUMERIC NOT NULL CHECK (hours > 0 AND hours <= 24)
);

-- No unique constraint on purpose: double-entered charges
-- (e.g. a truck rental entered twice) must load so checks can catch them.
CREATE TABLE job_costs (
    cost_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id    TEXT NOT NULL REFERENCES jobs(job_id),
    cost_type TEXT NOT NULL CHECK (cost_type IN ('truck', 'equipment', 'materials')),
    cost_date TEXT,
    amount    NUMERIC NOT NULL CHECK (amount >= 0)
);

-- Optional: only load this if payments are actually tracked.
CREATE TABLE payments (
    payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id     TEXT NOT NULL REFERENCES jobs(job_id),
    paid_date  TEXT NOT NULL,
    amount     NUMERIC NOT NULL CHECK (amount > 0)
);

CREATE INDEX idx_jobs_date      ON jobs(job_date);
CREATE INDEX idx_jobs_client    ON jobs(client_id);
CREATE INDEX idx_hours_job      ON crew_hours(job_id);
CREATE INDEX idx_hours_emp_date ON crew_hours(employee_id, work_date);
CREATE INDEX idx_costs_job      ON job_costs(job_id);
CREATE INDEX idx_payments_job   ON payments(job_id);
