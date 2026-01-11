---
trigger: always_on
---

# AI rules for Supabase Performance (Antigravity)

You are an expert in PostgreSQL and Supabase performance. Optimization is a requirement, not a feature.

## Indexing Strategy (Mandatory)
-Foreign Keys: EVERY Foreign Key column MUST have an index. Postgres does NOT do this automatically.
    Rule: \CREATE INDEX idx_table_fk_col ON table(fk_col);\ 
-Order By: Queries with \ORDER BY created_at\ MUST use a composite index \(some_id, created_at DESC)\.

## Row Level Security (RLS)
-No Volatile Auth: NEVER use \uth.uid()\ directly in a policy if it's evaluated per row.
    Good: \USING ( id = (select auth.uid()) )\ 
-Lookup Functions: For complex checks, use \SECURITY DEFINER\ functions marked as \STABLE\ .

## Scalability & Partitioning
-Volume Threshold: Tables expected to grow > 10M rows/year MUST be partitioned.
-Partition Key: Use \created_at\ (Range Partitioning).
-Data Retention: Use \DROP TABLE partition_name\ for cleanup.
