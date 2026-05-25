-- ============================================================
-- PART A: The KPI Contract (Conceptual)
-- ============================================================
-- Before writing any query, answer these for EACH exercise:
--
-- 1. What is the business question?
-- 2. What is the exact definition? (Include every filter, every join)
-- 3. What are the edge cases? (NULLs, cancelled tasks, unassigned tasks, etc.)
-- 4. What is the unit? (Count, percentage, hours, dollars?)
-- 5. What would make this metric misleading?
--
-- Write your answers as SQL comments above each query.
-- A query without a contract is just a number. A query WITH a contract
-- is a metric the business can trust.
--
-- Tom Kyte's rule: "If you cannot explain the metric to a non-technical
-- person in one sentence, your query is wrong."


-- ============================================================
-- EXERCISE 1: Define "Team Velocity"
-- ============================================================
--
-- Business context: Management wants to compare how fast each team
-- completes work. They ask for "team velocity."
--
-- YOUR TASK:
-- 1. Define the KPI contract in comments. What EXACTLY does "velocity" mean?
--    Is it tasks completed per day? Per person? Per story point?
--    (We do not have story points — how does that change the definition?)
-- 2. Write a query that shows each team's velocity with your chosen definition.
-- 3. Add a column that flags teams with velocity below the overall average.
--
-- Edge case to consider: The Product team has fewer people than Engineering.
-- Should velocity be normalized per team member? What are the pros and cons?

-- Team velocity is defined as the average number of completed tasks per team member during the measured time period. Since the system does not include story points or effort estimation, completed tasks are used as the unit of productivity. The calculation divides the number of tasks with status = 'completed' by the number of members in each team to normalize performance across teams of different sizes. This allows smaller teams, such as Product, to be compared more fairly against larger teams . However, this metric has limitations because it assumes all tasks have similar complexity and does not account for quality, difficulty, or business impact.
-- 
SELECT assigned_to, AVG((CAST(completed_at AS DATE) - created_at) * 24) AS avg_hours
FROM tasks
WHERE completed_at IS NOT NULL
GROUP BY assigned_to
ORDER BY avg_hours;



-- ============================================================
-- EXERCISE 2: Define "On-Time Delivery Rate"
-- ============================================================
--
-- Business context: The product manager wants to know: "Do we meet
-- our deadlines?" They ask for an "on-time delivery rate."
--
-- YOUR TASK:
-- 1. Define the KPI contract in comments. What does "on-time" mean?
--    Is it completed before due_date? Before end-of-day on due_date?
--    What about tasks with no due_date?
-- 2. Write a query that calculates the on-time delivery rate.
-- 3. Break it down by priority (critical, high, medium, low).
-- 4. Add a column showing the average "lateness" in hours for overdue tasks.
--
-- Edge case to consider: A task completed at 23:59 on the due date
-- vs. 00:01 the next day. Should both be "late"? Neither? Only one?
-- How does your choice affect the metric?

--Contract
-- On-time¿means the percentage of completed tasks finished
-- on or before their due_date. Tasks without a due_date are ignored.
-- A task completed after the due_date is considered late. The query also
-- shows the average lateness in hours for overdue tasks grouped by priority.

-- 
SELECT
    priority,

    ROUND(
        COUNT(
            CASE
                WHEN completed_at <= due_date THEN 1
            END
        ) * 100 / COUNT(*),
        2
    ) AS on_time_rate,

    ROUND(
        AVG(
            CASE
                WHEN completed_at > due_date
                THEN (completed_at - due_date) * 24
            END
        ),
        2
    ) AS avg_late_hours

FROM tasks

WHERE completed_at IS NOT NULL
AND due_date IS NOT NULL

GROUP BY priority;




-- ============================================================
-- PART B: Improve the Class KPIs
-- ============================================================
-- The KPIs from 03_kpi_queries.sql work, but they can be better.
-- For each exercise, identify the flaw and rewrite the query.


-- ============================================================
-- EXERCISE 3: Improve "Tasks per Team" (KPI 2 from class)
-- ============================================================
--
-- FLAW: The original query counts ALL tasks assigned to users in a team,
-- including completed and cancelled tasks. A team with 50 completed tasks
-- and 0 open tasks looks "busy" but has no current workload.
--
-- YOUR TASK:
-- 1. Rewrite the query to show THREE columns per team:
--    - total_tasks (all time)
--    - active_tasks (open + in_progress + blocked)
--    - completion_rate (completed / total, excluding cancelled)
-- 2. Add a "health score" column: a CASE expression that labels each team
--    as 'Overloaded' (active_tasks > 10), 'Healthy' (5-10), or 'Underutilized' (< 5).
-- 3. Order by active_tasks DESC so the busiest teams appear first.

-- Original (from 03_kpi_queries.sql — KPI 2):
-- SELECT t.name AS team_name,
--        COUNT(ts.id) AS task_count
-- FROM   teams t
-- LEFT   JOIN users u ON u.team_id = t.id
-- LEFT   JOIN tasks ts ON ts.assigned_to = u.id
-- GROUP  BY t.id, t.name
-- ORDER  BY task_count DESC;
--
-- Technique: LEFT JOIN chain. We start from teams (the dimension table)
-- and LEFT JOIN through users to tasks. This ensures teams with zero
-- tasks still appear (count = 0), which an INNER JOIN would hide.

-- [Write your improved query below]
SELECT
    t.name AS team_name,
    COUNT(ts.id) AS total_tasks,
    COUNT(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 END) AS active_tasks,
    ROUND(
        COUNT(CASE WHEN ts.status = 'completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(CASE WHEN ts.status != 'cancelled' THEN 1 END), 0),
        2
    ) AS completion_rate,
    CASE
        WHEN COUNT(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 END) > 10 THEN 'Overloaded'
        WHEN COUNT(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN 1 END) BETWEEN 5 AND 10 THEN 'Healthy'
        ELSE 'Underutilized'
    END AS health_score
FROM
    teams t
LEFT JOIN
    users u ON u.team_id = t.id
LEFT JOIN
    tasks ts ON ts.assigned_to = u.id
GROUP BY
    t.id, t.name
ORDER BY
    active_tasks DESC

-- ============================================================
-- EXERCISE 4: Improve "Average Resolution Time" (KPI 5 from class)
-- ============================================================
--
-- FLAW: The original query averages ALL completed tasks together.
-- A critical bug fixed in 2 hours and a documentation update fixed in
-- 40 hours are averaged together. The metric hides priority differences.
--
-- YOUR TASK:
-- 1. Rewrite the query to show average resolution time BY PRIORITY.
-- 2. Add a column showing the MEDIAN resolution time per priority.
--    (Hint: Oracle 23ai supports PERCENTILE_CONT. Research it.)
-- 3. Add a column showing the FASTEST and SLOWEST resolution time per priority.
--    (Hint: MIN and MAX, but only if you want simple extremes.)
-- 4. Add a "target met" column: For each priority, define a target SLA
--    (critical = 24h, high = 72h, medium = 168h, low = 336h) and flag
--    whether the average meets the target.
--
-- Edge case: What if a priority has only 1 completed task? Is the average meaningful?
-- How should you communicate that in the result?

-- Original (from 03_kpi_queries.sql — KPI 5):
-- SELECT ROUND(AVG(
--            EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
--            EXTRACT(HOUR FROM (completed_at - created_at)) +
--            EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
--        ), 1) AS avg_resolution_hours,
--        COUNT(*) AS completed_task_count
-- FROM   tasks
-- WHERE  status = 'completed'
--   AND  completed_at IS NOT NULL;
--
-- Technique: EXTRACT from INTERVAL. Oracle timestamp subtraction
-- returns a DAY TO SECOND interval. We break it into components.
-- We also report the count — an average of 2 tasks is not meaningful.

-- [Write your improved query below]
SELECT
    priority,

    COUNT(*) AS completed_tasks,

    ROUND(
        AVG((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24),
        1
    ) AS avg_resolution_hours,

    ROUND(
        MIN((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24),
        1
    ) AS fastest_hours,

    ROUND(
        MAX((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24),
        1
    ) AS slowest_hours,

    CASE
        WHEN priority = 'critical'
             AND AVG((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24) <= 24
        THEN 'Met'

        WHEN priority = 'high'
             AND AVG((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24) <= 72
        THEN 'Met'

        WHEN priority = 'medium'
             AND AVG((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24) <= 168
        THEN 'Met'

        WHEN priority = 'low'
             AND AVG((CAST(completed_at AS DATE) - CAST(created_at AS DATE)) * 24) <= 336
        THEN 'Met'

        ELSE 'Not Met'
    END AS target_met

FROM tasks

WHERE status = 'completed'

GROUP BY priority


-- ============================================================
-- EXERCISE 5: Improve "Overdue Tasks" (KPI 7 from class)
-- ============================================================
--
-- FLAW: The original query is a simple COUNT. It tells you HOW MANY
-- tasks are overdue, but not HOW OVERDUE, WHO owns them, or WHAT
-- the business impact is. A critical task 1 day late is different
-- from a low-priority task 30 days late.
--
-- YOUR TASK:
-- 1. Rewrite the query as a detailed report (not just a count).
--    Include: task title, assignee, team, priority, due_date,
--    days_overdue (calculated), and a "severity" column.
-- 2. Define severity as:
--    - 'CRITICAL': priority = 'critical' AND days_overdue > 0
--    - 'HIGH': priority = 'high' AND days_overdue > 2
--    - 'MEDIUM': priority = 'medium' AND days_overdue > 5
--    - 'LOW': everything else overdue
-- 3. Order by severity (most urgent first), then by days_overdue DESC.
-- 4. Add a summary row at the bottom (using ROLLUP or UNION) showing
--    total overdue count and average days overdue per severity level.

-- Original (from 03_kpi_queries.sql — KPI 7):
-- SELECT COUNT(*) AS overdue_count
-- FROM   tasks
-- WHERE  due_date < TRUNC(SYSDATE)
--   AND  status NOT IN ('completed', 'cancelled')
--   AND  due_date IS NOT NULL;
--
-- Technique: TRUNC(SYSDATE) gives today at midnight. We compare dates
-- without time-of-day to avoid false positives (a task due "today"
-- at 23:59 should not be flagged at 09:00).
-- NULL check is defensive — always filter out unknown due dates.

-- SELECT
    title,
    assignee,
    team,
    priority,
    due_date,
    days_overdue,
    severity,
    total_overdue_count,
    avg_days_overdue_severity
FROM
(
    WITH detailed_overdue AS (
        SELECT
            ts.title,
            u.full_name AS assignee,
            t.name AS team,
            ts.priority,
            ts.due_date,
            (TRUNC(SYSDATE) - TRUNC(ts.due_date)) AS days_overdue
        FROM
            tasks ts
        LEFT JOIN
            users u ON u.id = ts.assigned_to
        LEFT JOIN
            teams t ON t.id = u.team_id
        WHERE
            ts.due_date < TRUNC(SYSDATE)
            AND ts.status NOT IN ('completed', 'cancelled')
            AND ts.due_date IS NOT NULL
    ),
    overdue_with_severity AS (
        SELECT
            title,
            assignee,
            team,
            priority,
            due_date,
            days_overdue,
            CASE
                WHEN priority = 'critical' AND days_overdue > 0 THEN 'CRITICAL'
                WHEN priority = 'high' AND days_overdue > 2 THEN 'HIGH'
                WHEN priority = 'medium' AND days_overdue > 5 THEN 'MEDIUM'
                ELSE 'LOW'
            END AS severity
        FROM
            detailed_overdue
    )
   
    SELECT
        title,
        assignee,
        team,
        priority,
        due_date,
        days_overdue,
        severity,
        CAST(NULL AS NUMBER) AS total_overdue_count, 
        CAST(NULL AS NUMBER) AS avg_days_overdue_severity
    FROM
        overdue_with_severity
    UNION ALL
   
    SELECT
        '--- Summary for ' || severity || ' ---' AS title, 
        NULL AS assignee,
        NULL AS team,
        NULL AS priority,
        NULL AS due_date,
        NULL AS days_overdue,
        severity,
        COUNT(*) AS total_overdue_count,
        ROUND(AVG(days_overdue), 2) AS avg_days_overdue_severity
    FROM
        overdue_with_severity
    GROUP BY
        severity
)
ORDER BY
    CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        ELSE 5 
    END,
    days_overdue DESC NULLS LAST


-- ============================================================
-- PART C: The "Bad KPI" Challenge
-- ============================================================
-- Below are three queries that return numbers. Each is a BAD KPI.
-- Your task: Identify WHY it is bad, then rewrite it correctly.


-- ============================================================
-- EXERCISE 6: Fix the "Productivity Score"
-- ============================================================
--
-- BAD QUERY:
-- SELECT u.full_name, COUNT(ts.id) AS productivity_score
-- FROM users u
-- JOIN tasks ts ON ts.assigned_to = u.id
-- GROUP BY u.id, u.full_name
-- ORDER BY productivity_score DESC;
--
-- PROBLEM: ____________________________________________________
-- (What is wrong with this metric? Hint: Does it distinguish between
--  creating 10 tasks and completing 10 tasks? Does it handle unassigned
--  tasks? Does it account for task complexity or priority?)
--
-- REWRITE: Write a query that measures something actually meaningful.
-- Suggestion: "Completed tasks per day, weighted by priority."

-- PROBLEM:
-- This metric only counts assigned tasks, not completed tasks.
-- It also ignores task priority and task difficulty.

SELECT
    assigned_to,

    COUNT(*) AS completed_tasks

FROM tasks

WHERE status = 'completed'

GROUP BY assigned_to

ORDER BY completed_tasks DESC;

-- ============================================================
-- EXERCISE 7: Fix the "Team Efficiency"
-- ============================================================
--
-- BAD QUERY:
-- SELECT t.name, AVG(ts.id) AS avg_task_id
-- FROM teams t
-- JOIN users u ON u.team_id = t.id
-- JOIN tasks ts ON ts.assigned_to = u.id
-- GROUP BY t.id, t.name;
--
-- PROBLEM: ____________________________________________________
-- (What is mathematically wrong here? What does "average task ID" mean?)
--
-- REWRITE: Write a query that measures actual team efficiency.
-- Suggestion: "Ratio of completed tasks to total tasks, per team."

-- PROBLEM:
-- Average task ID has no business meaning because task IDs are
-- just identifiers, not performance measurements.

SELECT
    tm.team_name,

    ROUND(
        COUNT(
            CASE
                WHEN ts.status = 'completed' THEN 1
            END
        ) * 100 / COUNT(*),
        2
    ) AS completion_rate

FROM teams tm
JOIN users u
    ON tm.team_id = u.team_id
JOIN tasks ts
    ON ts.assigned_to = u.user_id

GROUP BY tm.team_name;


-- ============================================================
-- EXERCISE 8: Fix the "Urgency Index"
-- ============================================================
--
-- BAD QUERY:
-- SELECT title, priority * 10 + DUE_DATE AS urgency_index
-- FROM tasks
-- ORDER BY urgency_index DESC;
--
-- PROBLEM: ____________________________________________________
-- (What is wrong with adding a string and a number? What is wrong with
--  multiplying a VARCHAR by 10? What should the query actually do?)
--
-- REWRITE: Write a query that creates a real urgency score.
-- Suggestion: Assign numeric weights to priority (critical=4, high=3,
-- medium=2, low=1) and add days_until_due (negative if overdue).
-- A higher score = more urgent.

-- PROBLEM:
-- Priority is text, so it cannot be multiplied by numbers.
-- The query should convert priority into numeric values.

SELECT
    title,
    priority,
    due_date,

    CASE priority
        WHEN 'critical' THEN 4
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 1
    END
    +
    (SYSDATE - due_date) AS urgency_score

FROM tasks

WHERE due_date IS NOT NULL

ORDER BY urgency_score DESC;


-- ============================================================
-- PART D: Bonus — Build a Summary Dashboard Query
-- ============================================================
--
-- Write a SINGLE query that returns one row with ALL of the following:
-- 1. total_tasks
-- 2. completed_tasks
-- 3. active_tasks (open + in_progress + blocked)
-- 4. overdue_tasks
-- 5. completion_rate_pct
-- 6. avg_resolution_hours
-- 7. avg_days_overdue (for overdue tasks only)
-- 8. most_common_priority (the priority with the most active tasks)
-- 9. busiest_team (team with the most active tasks)
--
-- Use CTEs to build this step by step. Start with a "base" CTE that
-- enriches tasks with derived columns, then build metric CTEs from it.
--
-- This is the pattern real BI tools use: one query, many metrics.

-- [Write your mega-query below]
WITH base AS (

    SELECT
        t.task_id,
        t.status,
        t.priority,
        t.created_at,
        t.completed_at,
        t.due_date,
        u.user_id,
        tm.team_name,

        CASE
            WHEN t.status IN ('open', 'in_progress', 'blocked')
            THEN 1
            ELSE 0
        END AS is_active,

        CASE
            WHEN t.due_date < SYSDATE
                 AND t.status != 'completed'
            THEN 1
            ELSE 0
        END AS is_overdue,

        (CAST(t.completed_at AS DATE) - CAST(t.created_at AS DATE)) * 24
            AS resolution_hours,

        (SYSDATE - t.due_date)
            AS days_overdue

    FROM tasks t
    LEFT JOIN users u
        ON t.assigned_to = u.user_id
    LEFT JOIN teams tm
        ON u.team_id = tm.team_id
),

priority_counts AS (

    SELECT
        priority,
        COUNT(*) AS total_active
    FROM base
    WHERE is_active = 1
    GROUP BY priority
),

team_counts AS (

    SELECT
        team_name,
        COUNT(*) AS total_active
    FROM base
    WHERE is_active = 1
    GROUP BY team_name
)

SELECT

    COUNT(*) AS total_tasks,

    COUNT(
        CASE
            WHEN status = 'completed' THEN 1
        END
    ) AS completed_tasks,

    COUNT(
        CASE
            WHEN is_active = 1 THEN 1
        END
    ) AS active_tasks,

    COUNT(
        CASE
            WHEN is_overdue = 1 THEN 1
        END
    ) AS overdue_tasks,

    ROUND(
        COUNT(
            CASE
                WHEN status = 'completed' THEN 1
            END
        ) * 100 / COUNT(*),
        2
    ) AS completion_rate_pct,

    ROUND(
        AVG(resolution_hours),
        2
    ) AS avg_resolution_hours,

    ROUND(
        AVG(
            CASE
                WHEN is_overdue = 1
                THEN days_overdue
            END
        ),
        2
    ) AS avg_days_overdue,

    (
        SELECT priority
        FROM priority_counts
        WHERE total_active = (
            SELECT MAX(total_active)
            FROM priority_counts
        )
        FETCH FIRST 1 ROW ONLY
    ) AS most_common_priority,

    (
        SELECT team_name
        FROM team_counts
        WHERE total_active = (
            SELECT MAX(total_active)
            FROM team_counts
        )
        FETCH FIRST 1 ROW ONLY
    ) AS busiest_team

FROM base;

