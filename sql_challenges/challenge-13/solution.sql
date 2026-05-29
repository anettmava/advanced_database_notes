## Step 1 — Source Tables (OLTP)

Create two tables:

**`tickets`** — current state of each ticket. Needs:
- ticket_id, title, status, priority, created_at, resolved_at, assigned_to

**`ticket_assignments`** — history of who was assigned when. Needs:
- assignment_id, ticket_id, assigned_to, assigned_by, valid_from, valid_to

```sql
CREATE TABLE tickets (
    ticket_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR2(200) NOT NULL,
    status VARCHAR2(20) DEFAULT 'open' NOT NULL,
    priority VARCHAR2(10) DEFAULT 'medium' NOT NULL,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    assigned_to NUMBER,
    CONSTRAINT chk_ticket_status CHECK (
        status IN ('open', 'in_progress', 'blocked', 'resolved', 'closed')
    ),
    CONSTRAINT chk_ticket_priority CHECK (
        priority IN ('low', 'medium', 'high', 'critical')
    )
);

CREATE TABLE ticket_assignments (
    assignment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id NUMBER NOT NULL,
    assigned_to NUMBER NOT NULL,
    assigned_by NUMBER,
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,
    CONSTRAINT fk_ticket_assignment_ticket
        FOREIGN KEY (ticket_id)
        REFERENCES tickets(ticket_id)
);

CREATE INDEX idx_ticket_assignment_lookup
ON ticket_assignments (
    ticket_id,
    valid_from,
    valid_to
);
```

---

## Step 2 — Sample Data

Insert at least 5 tickets. Make sure at least one gets reassigned (different
person in `ticket_assignments` than the current `assigned_to` in `tickets`).

```sql
INSERT INTO tickets (
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
) VALUES (
    'Login page bug',
    'resolved',
    'high',
    TIMESTAMP '2026-05-01 09:00:00',
    TIMESTAMP '2026-05-03 15:00:00',
    3
);

INSERT INTO tickets (
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
) VALUES (
    'Database backup failure',
    'in_progress',
    'critical',
    TIMESTAMP '2026-05-02 10:00:00',
    NULL,
    2
);

INSERT INTO tickets (
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
) VALUES (
    'UI alignment issue',
    'open',
    'low',
    TIMESTAMP '2026-05-03 11:00:00',
    NULL,
    4
);

INSERT INTO tickets (
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
) VALUES (
    'API timeout errors',
    'blocked',
    'high',
    TIMESTAMP '2026-05-04 08:30:00',
    NULL,
    5
);

INSERT INTO tickets (
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
) VALUES (
    'Email notification issue',
    'resolved',
    'medium',
    TIMESTAMP '2026-05-05 14:00:00',
    TIMESTAMP '2026-05-06 16:30:00',
    1
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    1,
    2,
    1,
    TIMESTAMP '2026-05-01 09:00:00',
    TIMESTAMP '2026-05-02 12:00:00'
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    1,
    3,
    2,
    TIMESTAMP '2026-05-02 12:00:00',
    NULL
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    2,
    2,
    1,
    TIMESTAMP '2026-05-02 10:00:00',
    NULL
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    3,
    4,
    2,
    TIMESTAMP '2026-05-03 11:00:00',
    NULL
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    4,
    5,
    3,
    TIMESTAMP '2026-05-04 08:30:00',
    NULL
);

INSERT INTO ticket_assignments (
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
) VALUES (
    5,
    1,
    4,
    TIMESTAMP '2026-05-05 14:00:00',
    NULL
);

COMMIT;
```

---

## Step 3 — Trigger

Write a trigger on `tickets` that:
- On INSERT or UPDATE of `assigned_to`, logs the change to `ticket_assignments`
- Closes the previous active assignment (sets its `valid_to`)
- Inserts a new row with `valid_from = now()` and `valid_to = NULL`

```sql
CREATE OR REPLACE TRIGGER trg_ticket_assignment_log
AFTER INSERT OR UPDATE OF assigned_to ON tickets
FOR EACH ROW
BEGIN

    IF INSERTING THEN

        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            SYSTIMESTAMP,
            NULL
        );

    ELSIF UPDATING THEN

        UPDATE ticket_assignments
        SET valid_to = SYSTIMESTAMP
        WHERE ticket_id = :OLD.ticket_id
          AND valid_to IS NULL;

        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            :OLD.assigned_to,
            SYSTIMESTAMP,
            NULL
        );

    END IF;

END;
/
```

**Test it:** Reassign a ticket, then query `ticket_assignments` to confirm
both the old and new assignment are recorded.
UPDATE tickets
SET assigned_to = 4
WHERE ticket_id = 2;

COMMIT;

SELECT
    assignment_id,
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
FROM ticket_assignments
WHERE ticket_id = 2
ORDER BY valid_from;

---

## Step 4 — Data Warehouse Tables (Star Schema)

Create two tables:

**`dim_agent`** — agent details. Needs: agent_key, agent_name, team

**`fact_ticket_daily`** — daily counts per agent/status/priority. Needs:
date_key, agent_key, status, priority, tickets_created, tickets_resolved

```sql
-- BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE fact_ticket_daily';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE dim_agent';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE dim_agent (
    agent_key NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_name VARCHAR2(100) NOT NULL,
    team VARCHAR2(50) NOT NULL
);

CREATE TABLE fact_ticket_daily (
    date_key NUMBER NOT NULL,
    agent_key NUMBER NOT NULL,
    status VARCHAR2(20) NOT NULL,
    priority VARCHAR2(10) NOT NULL,
    tickets_created NUMBER DEFAULT 0,
    tickets_resolved NUMBER DEFAULT 0,
    CONSTRAINT fk_fact_agent
        FOREIGN KEY (agent_key)
        REFERENCES dim_agent(agent_key)
);
```

---

## Step 5 — Populate dim_agent

Insert 3-4 agents with their teams.

```sql
-- INSERT INTO dim_agent (agent_name, team)
VALUES ('Monse', 'Support');

INSERT INTO dim_agent (agent_name, team)
VALUES ('Wynter', 'Infrastructure');

INSERT INTO dim_agent (agent_name, team)
VALUES ('Annete', 'Frontend');

INSERT INTO dim_agent (agent_name, team)
VALUES ('Sarah', 'Backend');

COMMIT;
```

---

## Step 6 — ETL Logic (Colab)

In your Colab notebook, write pandas code that:
1. Extracts `tickets` and `ticket_assignments` from FreeSQL
2. For each ticket, finds who was assigned at `created_at` using:
   `valid_from <= created_at AND (valid_to IS NULL OR valid_to > created_at)`
3. Same for `resolved_at`
4. Groups by date, agent, status, priority and counts
5. Inserts into `fact_ticket_daily`


!pip install oracledb pandas -q

import pandas as pd
import oracledb

connection = oracledb.connect(
    user="A01645033_SCHEMA_MXVOZ",
    password="A01645033_SCHEMA_MXOZ",
    dsn="tcps://db.freesql.com:2414/23ai_34ui2"
)

tickets_df = pd.read_sql("""
SELECT
    ticket_id,
    title,
    status,
    priority,
    created_at,
    resolved_at,
    assigned_to
FROM tickets
""", connection)

assignments_df = pd.read_sql("""
SELECT
    assignment_id,
    ticket_id,
    assigned_to,
    assigned_by,
    valid_from,
    valid_to
FROM ticket_assignments
""", connection)

tickets_df["created_at"] = pd.to_datetime(tickets_df["created_at"])
tickets_df["resolved_at"] = pd.to_datetime(tickets_df["resolved_at"])

assignments_df["valid_from"] = pd.to_datetime(assignments_df["valid_from"])
assignments_df["valid_to"] = pd.to_datetime(assignments_df["valid_to"])

def find_agent(ticket_id, timestamp):

    if pd.isna(timestamp):
        return None

    rows = assignments_df[
        (assignments_df["ticket_id"] == ticket_id) &
        (assignments_df["valid_from"] <= timestamp) &
        (
            assignments_df["valid_to"].isna() |
            (assignments_df["valid_to"] > timestamp)
        )
    ]

    if rows.empty:
        return None

    return rows.iloc[0]["assigned_to"]

tickets_df["created_agent"] = tickets_df.apply(
    lambda row: find_agent(
        row["ticket_id"],
        row["created_at"]
    ),
    axis=1
)

tickets_df["resolved_agent"] = tickets_df.apply(
    lambda row: find_agent(
        row["ticket_id"],
        row["resolved_at"]
    ),
    axis=1
)

created_facts = tickets_df.copy()

created_facts["date_key"] = (
    created_facts["created_at"]
    .dt.strftime("%Y%m%d")
    .astype(int)
)

created_facts["agent_key"] = created_facts["created_agent"]

created_facts["tickets_created"] = 1
created_facts["tickets_resolved"] = 0

created_facts = created_facts[
    [
        "date_key",
        "agent_key",
        "status",
        "priority",
        "tickets_created",
        "tickets_resolved"
    ]
]

resolved_facts = tickets_df[
    tickets_df["resolved_at"].notna()
].copy()

resolved_facts["date_key"] = (
    resolved_facts["resolved_at"]
    .dt.strftime("%Y%m%d")
    .astype(int)
)

resolved_facts["agent_key"] = resolved_facts["resolved_agent"]

resolved_facts["tickets_created"] = 0
resolved_facts["tickets_resolved"] = 1

resolved_facts = resolved_facts[
    [
        "date_key",
        "agent_key",
        "status",
        "priority",
        "tickets_created",
        "tickets_resolved"
    ]
]

fact_df = pd.concat(
    [created_facts, resolved_facts],
    ignore_index=True
)

fact_df = (
    fact_df
    .groupby(
        [
            "date_key",
            "agent_key",
            "status",
            "priority"
        ],
        as_index=False
    )
    .sum()
)

cursor = connection.cursor()

insert_query = """
INSERT INTO fact_ticket_daily (
    date_key,
    agent_key,
    status,
    priority,
    tickets_created,
    tickets_resolved
)
VALUES (
    :1,
    :2,
    :3,
    :4,
    :5,
    :6
)
"""

for _, row in fact_df.iterrows():

    cursor.execute(
        insert_query,
        (
            int(row["date_key"]),
            int(row["agent_key"]),
            row["status"],
            row["priority"],
            int(row["tickets_created"]),
            int(row["tickets_resolved"])
        )
    )

connection.commit()

cursor.close()
connection.close()
---

## Step 7 — Verify

Write a query joining `fact_ticket_daily` and `dim_agent` to show tickets
created and resolved per agent per day. The reassigned ticket should show
the original agent for creation and the new agent for resolution.

```sql
-- 
SELECT
    f.date_key,
    d.agent_name,
    d.team,
    f.status,
    f.priority,
    SUM(f.tickets_created) AS tickets_created,
    SUM(f.tickets_resolved) AS tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent d
    ON f.agent_key = d.agent_key
GROUP BY
    f.date_key,
    d.agent_name,
    d.team,
    f.status,
    f.priority
ORDER BY
    f.date_key,
    d.agent_name;
```