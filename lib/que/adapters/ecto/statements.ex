defmodule DQ.Adapters.Ecto.Statments do
  def ack do
    "DELETE FROM jobs where id = $1"
  end

  def nack do
  """
UPDATE jobs SET
  error_count = error_count + 1,
  error_message = $1,
  status = 'pending',
  scheduled_at = now() at time zone 'UTC' + ($2::text || ' ' || 'seconds'::text)::interval,
  dequeued_at = NULL,
  deadline_at = NULL
WHERE
  id = $3
    """
  end

  def nack_dead do
  """
UPDATE jobs SET
  error_count = error_count + 1,
  error_message = $1,
  status = 'dead',
  dequeued_at = NULL,
  deadline_at = NULL
WHERE
  id = $2
    """
  end

  def pop do
    """
WITH candidates AS (
   SELECT id, payload,
      scheduled_at as scheduled_at
   FROM jobs
   WHERE
     dequeued_at IS NULL
     AND
     status = 'pending'
   ORDER BY scheduled_at nulls first
   LIMIT 1
 ),  selected AS (
   SELECT id FROM candidates
   WHERE
      scheduled_at <= now() at time zone 'utc' OR scheduled_at is NULL
      AND
      pg_try_advisory_xact_lock(id)
   ORDER BY scheduled_at nulls first
   LIMIT 1
)
UPDATE jobs SET
  status = 'running',
  dequeued_at = now() at time zone 'utc',
  deadline_at = now() at time zone 'utc' + (jobs.max_runtime_seconds::text || ' ' || 'seconds'::text)::interval
WHERE id = (SELECT id FROM selected)
AND dequeued_at IS NULL
RETURNING
   id,
   queue,
   status,
   payload,
   error_count,
   error_message,
   max_runtime_seconds
 """
  end

  def retry do
  """
UPDATE jobs SET
  error_count = 0,
  error_message = NULL,
  status = 'pending',
  dequeued_at = NULL,
  deadline_at = NULL
WHERE
  id = $1
    """
  end

  def dead do
    "SELECT * from jobs where status = 'dead' limit $1"
  end

  def purge do
    "DELETE FROM jobs"
  end

  def dead_purge do
    "DELETE FROM jobs where status = 'dead'"
  end

  def info do
    """
select
  (select count(*) from jobs where status = 'pending' AND scheduled_at IS NULL) as pending,
  (select count(*) from jobs where status = 'pending' AND scheduled_at IS NOT NULL) as delayed,
  (select count(*) from jobs where status = 'running') as running,
  (select count(*) from jobs where status = 'dead') as dead;
    """
  end
end
