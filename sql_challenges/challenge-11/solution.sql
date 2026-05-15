# Exercise 1 — Model Design (10 min)

## Scenario

Your task system needs a `comments` table.

Each comment belongs to:
- one task
- one user

---

## Task

Create a new Colab cell and write the `Comment` model.

### Required Fields

- `id`
- `task_id`
- `user_id`
- `content`
- `created_at`

---

## Questions

1. What relationships should `Comment` have?
With task and user.

2. Should `Task` have a `comments` relationship?
Yes, Task should have a comments relationship so that all comments associated with a task can be accessed easily.

3. What should happen to comments when a task is deleted?
When a task is deleted, its comments should usually be deleted as well to avoid records that reference a task that no longer exists. 


class Comment(Base):
    __tablename__ = "comments"
    id         = Column(Integer, primary_key=True)
    task_id    = Column(Integer, ForeignKey("tasks.id"))
    user_id    = Column(Integer, ForeignKey("users.id"))
    content    = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.current_timestamp())

    task = relationship("Task", backref="comments")
    user = relationship("User", backref="comments")

    def __repr__(self):
        return f"<Comment(id={self.id}, task_id={self.task_id}, user_id={self.user_id})>"

print("Comment model defined")

# Exercise 2 — Migration Creation (10 min)

## Scenario

You added the `Comment` model.

Now generate a migration programmatically.

---

## Task

Run:

```python
command.revision(
    alembic_cfg,
    autogenerate=True,
    message="add comments table"
)
```

---

## Then Inspect the Migration

```python
import glob

migration_files = sorted(
    glob.glob('/content/project/alembic/versions/*.py')
)

for f in migration_files:
    print(f)
```

---

## Open the Generated Migration

```python
latest = migration_files[-1]

with open(latest) as f:
    print(f.read())
```

---

## Questions

1. What does `upgrade()` do?
It applies the migration changes to the db

2. What does `downgrade()` do?
It goes back to the past version of the data base

3. What happens if you downgrade this migration?
The comments table will be deleted from the database, any comment data stored in that table will also be lost.
---

# Exercise 3 — CRUD Challenge (10 min)

## Scenario

Write a script that:

1. Creates a team called `"DevOps"`
2. Creates a user `"diana_ops"`
3. Creates 3 tasks with different priorities
4. Prints task count
5. Closes one task
6. Deletes the lowest priority task

---

## Requirements

- Use ORM only
- Use relationships
- Print output clearly

with Session(engine) as session:
  
    devops_team = Team(name="DevOps", description="Operations and Infrastructure team")
    session.add(devops_team)
    session.commit()
    print(f"\nCreated team: {devops_team}")


    diana_ops = User(username="diana_ops", email="diana.ops@example.com", full_name="Diana Ops", team=devops_team)
    session.add(diana_ops)
    session.commit()
    print(f"Created user: {diana_ops} in {devops_team.name}")

    task1 = Task(title="Deploy on OCI", description="Deploy the project on OCI", status="open", assigned_to=diana_ops.id)
    task2 = Task(title="Do a migration", description="Perform a db migration", status="open", assigned_to=diana_ops.id)
    task3 = Task(title="Finish documentation", description="Create diagrams of the infrastructure", status="open", assigned_to=diana_ops.id)

    session.add_all([task1, task2, task3])
    session.commit()
    print(f"\nCreated tasks for {diana_ops.full_name}:")
    for task in diana_ops.tasks:
        print(f"   - {task.title} (Status: {task.status})")

 
    diana_tasks_count = len(diana_ops.tasks) # Or session.query(Task).filter_by(assigned_to=diana_ops.id).count()
    print(f"\n{diana_ops.full_name} has {diana_tasks_count} tasks.")


    task_to_close = session.query(Task).filter_by(assigned_to=diana_ops.id, title="Deploy new monitoring system").first()
    if task_to_close:
        task_to_close.status = "closed"
        session.commit()
        print(f"\nClosed task: '{task_to_close.title}' (New Status: {task_to_close.status})")
    else:
        print("\nTask to close not found.")

  
    task_to_delete = session.query(Task).filter_by(assigned_to=diana_ops.id, title="Document network topology").first()
    if task_to_delete:
        session.delete(task_to_delete)
        session.commit()
        print(f"Deleted task: '{task_to_delete.title}'")
    else:
        print("\nTask to delete not found.")

    session.refresh(diana_ops) # Refresh the relationship to reflect changes
    print(f"\n{diana_ops.full_name}'s remaining tasks:")
    if diana_ops.tasks:
        for task in diana_ops.tasks:
            print(f"   - {task.title} (Status: {task.status})")
    else:
        print("   No tasks remaining.")

    
Created team: <Team(id=21, name='DevOps')>
Created user: <User(id=21, username='diana_ops')> in DevOps

Created tasks for Diana Ops:
   - Deploy on OCI (Status: open)
   - Do a migration (Status: open)
   - Finish documentation (Status: open)

Diana Ops has 3 tasks.

Task to close not found.

Task to delete not found.

Diana Ops's remaining tasks:
   - Deploy on OCI (Status: open)
   - Do a migration (Status: open)
   - Finish documentation (Status: open)


## Task

Rollback the migration programmatically.

### Example

```python
command.downgrade(alembic_cfg, "-1")
```

---

## Questions

1. What happens to the column?
The column or table added by the migration is removed from the database because the downgrade reverses the changes made in the upgrade() function

2. What happens to the data?
The column or table added by the migration is removed from the database because the downgrade reverses the changes made in the upgrade() function

# Exercise 5 — Concept Check (5 min)

Answer briefly:

1. Why use ORM instead of raw SQL?
ORM is useful because it lets developers work with  objects instead of writing raw SQL queries manually, making code easier to read, maintain, and reuse
2. Why use migrations?
Migrations are used to safely manage and track database schema changes over time so all developers and environments stay synchronized.
3. When would you rollback?
You would rollback when a migration introduces errors, breaks the application, or when you need to undo unwanted database changes.
4. Difference between `add()` and `commit()`?
add() places an object into the SQLAlchemy session, while commit() permanently saves the changes to the database.
5. Why are relationships useful?
Relationships are useful because they make it easy to connect and navigate related data between tables, such as accessing a task’s comments or a user’s tasks.