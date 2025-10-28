# Transaction Safety Guidelines

## Overview

This document describes the transaction management patterns used in Keep to prevent common issues like:
- `InvalidRequestError: A transaction is already begun on this Session`
- Nested transaction conflicts
- Uncommitted changes
- Session lifecycle management issues

## Core Principles

### 1. **Session Ownership Rule**
- The code that creates a session is responsible for closing it
- If you receive a session as a parameter, **never** close it
- Use context managers to ensure proper cleanup

### 2. **Transaction Ownership Rule**  
- The code that starts a transaction is responsible for committing/rolling back
- If you receive a session that may already have a transaction, **don't** call `session.begin()` again
- Let the caller manage the transaction boundaries

### 3. **Avoid Nested Transactions**
- SQLAlchemy doesn't support true nested transactions by default
- Calling `session.begin()` on an active transaction raises `InvalidRequestError`
- Use savepoints for nested behavior if truly needed

## Helper Functions

### `use_session(session: Optional[Session] = None)`

**Purpose:** Safely obtain a session, creating one only if needed.

**Behavior:**
- If `session` is provided: yields it without closing
- If `session` is `None`: creates new session and closes it on exit

**Usage:**
```python
# Create and manage new session
with use_session() as session:
    session.add(obj)
    session.commit()
# Session automatically closed

# Use existing session
with use_session(existing_session) as session:
    session.add(obj)
    # session.commit()  # Caller's responsibility
# Session NOT closed (caller owns it)
```

### `use_transaction(session: Optional[Session] = None)`

**Purpose:** Ensure atomic operations with automatic commit/rollback.

**Behavior:**
- If `session` is provided: assumes caller manages transaction, just yields it
- If `session` is `None`: creates new session + transaction, commits on success, rolls back on error

**Usage:**
```python
# Create and manage transaction
with use_transaction() as session:
    session.add(obj1)
    session.add(obj2)
    # Automatic commit on success, rollback on exception

# Use existing session (caller manages transaction)
with use_transaction(existing_session) as session:
    session.add(obj)
    # No commit/rollback here - caller handles it
```

**⚠️ Important:** When passing a session to `use_transaction()`, the caller is responsible for committing. This prevents nested transaction conflicts.

### `run_in_txn(fn, *args, session=None, **kwargs)`

**Purpose:** Execute a callable within a transaction.

**Usage:**
```python
def update_user(session: Session, user_id: int, name: str):
    user = session.get(User, user_id)
    user.name = name
    session.add(user)

# Create new session + transaction
run_in_txn(update_user, user_id=123, name="Alice")

# Use existing session
run_in_txn(update_user, user_id=123, name="Alice", session=my_session)
```

## Common Patterns

### Pattern 1: Top-Level Function (Creates Session)

```python
def process_alerts(alert_data: List[dict]):
    """Top-level function creates and owns the session."""
    with use_session() as session:
        with session.begin():
            for data in alert_data:
                alert = Alert(**data)
                session.add(alert)
            # Commits here on success
```

### Pattern 2: Helper Function (Receives Session)

```python
def save_alert(alert: Alert, session: Session):
    """Helper receives session, doesn't commit or close."""
    session.add(alert)
    # No commit - caller decides when to commit
    # No close - caller owns the session
```

### Pattern 3: Service Method (Optional Session)

```python
def create_service(name: str, session: Optional[Session] = None):
    """Can work standalone or as part of larger transaction."""
    with use_session(session) as s:
        service = Service(name=name)
        s.add(service)
        
        if session is None:
            # We created the session, we commit
            s.commit()
        # else: caller commits
```

### Pattern 4: Batch Operations (Single Transaction)

```python
def batch_insert_alerts(alerts: List[Alert], session: Session):
    """
    Batch operation within existing transaction.
    Assumes caller has already started a transaction.
    """
    session.add_all(alerts)
    # No commit - this is a batch helper
    # Caller will commit the entire batch

# Usage:
with session.begin():
    batch_insert_alerts(alerts_batch_1, session)
    batch_insert_alerts(alerts_batch_2, session)
    update_counters(session)
    # Single commit for everything
```

## Anti-Patterns (Don't Do This)

### ❌ Anti-Pattern 1: Nested `session.begin()`

```python
def outer():
    with session.begin():  # ✅ First begin
        inner(session)

def inner(session):
    with session.begin():  # ❌ ERROR: Already in transaction!
        session.add(obj)
```

**Fix:** Remove the inner `session.begin()`:
```python
def inner(session):
    session.add(obj)  # ✅ Use existing transaction
```

### ❌ Anti-Pattern 2: Helper Commits Mid-Transaction

```python
def process_batch(items, session):
    with session.begin():
        for item in items:
            save_item(item, session)  # ❌ save_item calls commit!

def save_item(item, session):
    session.add(item)
    session.commit()  # ❌ Commits partial batch!
```

**Fix:** Let the caller manage commits:
```python
def save_item(item, session):
    session.add(item)  # ✅ No commit
```

### ❌ Anti-Pattern 3: Closing Passed-In Session

```python
def helper(session: Session):
    try:
        session.add(obj)
        session.commit()
    finally:
        session.close()  # ❌ Caller's session destroyed!
```

**Fix:** Only close sessions you created:
```python
def helper(session: Session):
    session.add(obj)
    # Caller handles commit and close
```

## Testing Transaction Safety

When writing tests, verify:

1. **No double-begin errors:**
   ```python
   with session.begin():
       my_function(session)  # Should not call begin() again
   ```

2. **Proper cleanup:**
   ```python
   session = get_session()
   try:
       my_function(session)
   finally:
       session.close()
   # Verify no resource leaks
   ```

3. **Atomic operations:**
   ```python
   with pytest.raises(ValueError):
       with session.begin():
           process_data(bad_data, session)
   # Verify rollback occurred
   assert session.query(Model).count() == original_count
   ```

## Migration Checklist

When refactoring code for transaction safety:

- [ ] Identify who creates the session (top-level function)
- [ ] Remove `session.close()` from functions that receive session as param
- [ ] Remove `session.begin()` from nested functions
- [ ] Move `session.commit()` to the outermost transaction scope
- [ ] Use `use_session()` / `use_transaction()` helpers
- [ ] Add docstrings documenting transaction behavior
- [ ] Test with existing session to ensure no conflicts

## Related Issues

- **Idle in Transaction:** Long-running transactions hold locks. Keep transactions short by moving non-DB work outside transaction blocks.
- **Connection Pool Exhaustion:** Ensure sessions are always closed. Use context managers.
- **Deadlocks:** Can occur with nested transactions or long-held locks. Keep transaction scope minimal.

## Summary

**Golden Rules:**
1. Use context managers for all session/transaction management
2. Functions that receive a session should NOT close it
3. Functions that receive a session should NOT start a new transaction (unless using savepoints)
4. Commit at the highest level where you have complete context
5. Keep transaction scope as small as possible

