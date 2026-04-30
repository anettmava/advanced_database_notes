-- Lesson 04: Class Exercises
-- Students: work through these in order. Don't skip the verify steps.

-- ============================================================
-- EXERCISE 1: Manual transaction (warm-up)
-- ============================================================
-- Transfer $50 from Charlie (3) to Alice (1) using BEGIN / COMMIT manually.
-- Before: verify balances. After COMMIT: verify again.

-- Your SQL here:

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

UPDATE accounts
SET balance = balance 
WHERE account_id = 3;

UPDATE accounts
SET balance = balance 
WHERE account_id = 1; 

COMMIT;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

 

-- ============================================================
-- EXERCISE 2: Catch yourself with ROLLBACK
-- ============================================================
-- Start a transfer of $10,000 from Bob (2) to Charlie (3).
-- Before committing, check the balances. Does Bob have enough?
-- Use ROLLBACK to undo. Verify balances restored.

-- Your SQL here:
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

UPDATE accounts
SET balance = balance 
WHERE account_id = 2; 
UPDATE accounts
SET balance = balance
WHERE account_id = 3; 

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

ROLLBACK;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;


-- ============================================================
-- EXERCISE 3: SAVEPOINT checkpoint
-- ============================================================
-- You need to:
-- 1. Add $25 to Alice's balance
-- 2. Set a savepoint
-- 3. Deduct $25 from Charlie's balance (wrong account — you meant Bob)
-- 4. Rollback to savepoint
-- 5. Deduct $25 from Bob's balance instead
-- 6. Commit

-- Your SQL here:
UPDATE accounts
SET balance = balance + 25
WHERE account_id = 1;

SAVEPOINT sp_after_alice;

UPDATE accounts
SET balance = balance 
WHERE account_id = 3;

ROLLBACK TO sp_after_alice;

UPDATE accounts
SET balance = balance 
WHERE account_id = 2;

COMMIT;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

 

-- ============================================================
-- EXERCISE 4: Write your own stored procedure
-- ============================================================
-- Create a procedure called deposit_funds(p_account_id, p_amount)
-- It should:
-- 1. Validate that p_amount > 0 (raise error if not)
-- 2. Add p_amount to the account balance
-- 3. COMMIT on success
-- 4. ROLLBACK + re-raise on any error
-- Test it with: EXEC deposit_funds(3, 75);

-- Your SQL here:
CREATE OR REPLACE PROCEDURE deposit_funds (
    p_account_id IN NUMBER,
    p_amount     IN NUMBER
)
IS
BEGIN

    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El monto debe ser mayor a 0');
    END IF;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE; 
END;
/

 

-- ============================================================
-- EXERCISE 5: Discussion
-- ============================================================
-- Answer these in words (no SQL needed):

-- Q1: You're building a patient appointment booking system.
-- A booking requires:
--   a) Reserve the time slot
--   b) Create the appointment record
--   c) Send a confirmation notification
-- Which of these should be inside the transaction? Which should be outside? Why?
These two operations are directly related to the booking data and must happen together, if one succeeds and the other fails, the system would become inconsistent. For example, a slot could be reserved without an appointment being created.
The action that should be outside the transaction is: Send a confirmation notification this should happen after the transaction is committed because sending a notification is not part of the database consistency, if the notification fails, the appointment should still remain booked, and the message can be retried later.

-- Q2: Your stored procedure calls COMMIT at the end.
-- A developer calls your procedure from inside their own larger transaction.
-- What problem does this create?
If a stored procedure performs a COMMIT at the end, it removes control from the developer who called it, if that developer is running a larger transaction with several operations, the procedure will permanently save its changes before the rest of the transaction is finished.
 If another later step fails, the developer cannot roll back everything as one unit, this breaks transaction atomicity and makes partial commits possible, which can leave the database in an inconsistent state.

-- Q3: You have a function called calculate_copay() and a procedure called post_payment().
-- A colleague wants to use calculate_copay() inside a SELECT statement.
-- Can they? Can they do the same with post_payment()? Why or why not?

Yes, calculate_copay can be used inside a SELECT statement because it is a function. 
Functions return a value and are designed to be called within SQL expressions. 
No, post_payment() cannot be used the same way because it is a procedure. Procedures perform actions but do not return a value that SQL can directly use inside a query.
Also, procedures often modify data, while SELECT statements are intended only for retrieving information.

 