# Gym Database Project (Trimmed for Full-Credit Rubric Coverage)

## Files
- `mysql_schema.sql`: Physical model + indexes + scripted seed data.
- `mysql_queries.sql`: Views, retrieval SQL, procedures/functions, and triggers.
- `mongo_setup.js`: Mongo model sample data + complex aggregation demos.

## MySQL rubric coverage

### ER/EER + physical design
- Supertype/subtype: `person` -> `member`, `employee` (shared PK/FK 1:1 mapping).
- Includes 14 tables total, including 3 associative bridge tables:
  - `member_class_enrollment` (`member` <-> `class_session`)
  - `trainer_specialty` (`employee` <-> `specialty`)
  - `member_goal` (`member` <-> `goal`)
- Includes well over 5 FK relationships.

### Normalization to BCNF
- Each table has atomic attributes (1NF).
- Non-key attributes depend on whole key in composite-key tables (2NF).
- No transitive dependencies between non-key attributes (3NF).
- Determinants are candidate keys in each table (BCNF).

### Views (required mix)
- Aggregate view: `vw_member_class_counts`
- Window-function view: `vw_trainer_salary_rank`
- Correlated-subquery view: `vw_highly_active_members`

### Functions and procedures
- Functions:
  - `fn_membership_days`
  - `fn_member_attendance_rate`
- Procedures:
  - `sp_register_member_for_session`
  - `sp_log_equipment_maintenance`

### Triggers (different functionality)
- `trg_class_session_validate`: validation/business rule trigger.
- `trg_maintenance_updates_equipment`: state automation trigger.

### Indexes
- `idx_person_name`: directory/search by member name.
- `idx_session_start`: schedule-by-date queries.
- `idx_session_trainer_start`: trainer calendar lookups.
- `idx_enrollment_session_status`: roster/attendance queries.
- `idx_membership_member_active`: active membership checks.

### Data volume
- Scripted loader `sp_seed_test_data(220)` creates 220 members and corresponding rows in core operational tables.

## Mongo rubric coverage

### Database model + pattern defense
- Hybrid pattern:
  - Embedding: `members.currentMembership`, `members.goals`.
  - Referencing + lookups: `enrollments`, `classSessions`, `membershipPlans`, `employees`.
- Rationale: embed bounded, frequently-read member profile data; reference high-cardinality enrollment/session data.

### Complex Mongo queries
- Query 1: member + plan enrichment via `$lookup`.
- Query 2: session occupancy via `$group` + `$lookup`.
- Query 3: members above average enrollments via `$setWindowFields` + `$lookup`.

## Run
```sql
SOURCE mysql_schema.sql;
SOURCE mysql_queries.sql;
```

```javascript
load('mongo_setup.js');
```
