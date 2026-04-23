

-- ============================================================
-- Lesson 03 — Indexes: Class Exercises
-- Work through these before looking at the hints
-- ============================================================

-- ============================================================
-- Exercise 1 — Find the slow query
--
-- Run this query. Look at the execution plan.
-- Is Oracle using an index? Should it?
-- ============================================================

EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE site_id = 3;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) What scan type do you see? Why?
TABLE ACCESS FULL. Oracle has no index on site_id, so it must read every row in the table to find matches. There's no shortcut available.
-- b) site_id has values 1–5. Is this high or low cardinality?
Low cardinality.
-- c) Would adding an index on site_id help? Why or why not?
Probably not, since there are only five possible values, each one matches a  chunk of the table, most likely it willjust scan the whole table anyway because it's faster than using an index when so many rows match.

-- ============================================================
-- Exercise 2 — Create an index and see if it helps
--
-- Create an index on visit_date.
-- Then run the range query below and check the plan.
-- ============================================================

-- Step 1: Create it
-- (write the CREATE INDEX statement here)


-- Step 2: Gather stats
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

-- Step 3: Run the range query and check the plan
EXPLAIN PLAN FOR
SELECT * FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 30 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) Does Oracle use the index for this range?
Yes
-- b) Change the range to the last 7 days. Does the plan change?
No
-- c) Change to the last 700 days. What happens?
It doesnt change.
-- d) Why does the range size affect whether Oracle uses the index?

When the range covers too many rows, it's quicker to just read the whole table instead of going through the index.
-- ============================================================
-- Exercise 3 — Composite index
--
-- You often query by both patient_id AND visit_date together:
--   WHERE patient_id = 1234 AND visit_date > SYSDATE - 90
--
-- Two options:
--   Option A: Two separate indexes (one per column)
--   Option B: One composite index (patient_id, visit_date)
--
-- Create the composite index and test the query.
-- ============================================================

CREATE INDEX idx_pv_patient_date ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

EXPLAIN PLAN FOR
SELECT * FROM patient_visits
WHERE patient_id = 1234
  AND visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) Does the plan use the composite index?
Yes. The query filters on patient_id (the leading column) and then visit_date, which is the column order of idx_pv_patient_date
-- b) Now try querying ONLY on visit_date (no patient_id).
--    Does the composite index get used? Why not?
No, the composite index is sorted first by patient_id then by visit_date within each patient_id group. Without a patient_id filter there's no way to jump to a useful starting point in the index
-- c) What's the rule about column order in composite indexes?
can only use a composite index efficiently when the query filters start from the leftmost column. 
-- Bonus test — leading column only:
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE patient_id = 1234;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Trailing column only (index cannot be used from the middle):
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE visit_date > SYSDATE - 90;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- ============================================================
-- Exercise 4 — Function that breaks an index
--
-- There IS an index on patient_id (from lesson 03).
-- Predict what happens when you wrap the column in a function.
-- ============================================================

-- This query CAN use the index:
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE patient_id = 5432;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- This one cannot — why?
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE TO_CHAR(patient_id) = '5432';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) What scan type did the second query use?
Table access full
-- b) Why does wrapping a column in a function break index use?
he index saves the original values of the column.
-- c) How would you rewrite the second query to allow index use?
Comparing as number and not adding functions to the column WHERE patient_id = 5432
-- ============================================================
-- Exercise 5 — Discussion: real-world scenarios
--
-- For each scenario below, decide:
--   a) Would you add an index?
--   b) On which column(s)?
--   c) Any concerns?

-- ============================================================

-- Scenario A:
-- A reporting table gets loaded once per night (batch ETL).
-- During the day, analysts run SELECT queries by date range.
-- The table has 50 million rows.
-- → Index on date? Yes/No, why?
Yes, on visit_date because we can jump directly ro the row, but
be careful because the index can grow large if the table is big

-- Scenario B:
-- An OLTP orders table gets 10,000 inserts per minute.
-- Support staff look up orders by customer_id or order_status.
-- order_status has 4 values: pending, processing, shipped, cancelled.
-- → What indexes would you add?
Yes, i would add an index being careful because too many indexes affect performance


-- Scenario C:
-- A patient table has an email column (unique per patient).
-- There are 5 million patients.
-- The app frequently does: WHERE email = 'user@example.com'
-- → What kind of index would be best here?
Add index to email column, a unique index to make sure no rows have the same email


