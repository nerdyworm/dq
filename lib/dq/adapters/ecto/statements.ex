defmodule DQ.Adapters.Ecto.Statements do
  def insert do
    "INSERT INTO $TABLE$ (payload, max_runtime_seconds, scheduled_at) VALUES($1,$2,$3) returning id"
  end

  def ack do
    "DELETE FROM $TABLE$ where id = $1"
  end

  def nack do
    """
    UPDATE $TABLE$ SET
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
    UPDATE $TABLE$ SET
    error_count = error_count + 1,
    error_message = $1,
    status = 'dead',
    dequeued_at = NULL,
    deadline_at = NULL
    WHERE
    id = $2
    """
  end

  def pop(limit) do
    """
    with cte as (
      SELECT id FROM $TABLE$
      WHERE
        status = 'pending'
      AND
        scheduled_at <= now() at time zone 'utc' OR scheduled_at is NULL
      AND
        dequeued_at IS NULL
      LIMIT #{limit}
      FOR UPDATE SKIP LOCKED
    )
    update $TABLE$ set
     status = 'running',
     dequeued_at = now() at time zone 'utc',
     deadline_at = now() at time zone 'utc' + ($TABLE$.max_runtime_seconds::text || ' ' || 'seconds'::text)::interval
    FROM cte
    WHERE cte.id = $TABLE$.id
    RETURNING *
    """
  end

  def retry_timeouts do
    """
    UPDATE $TABLE$
      set status = 'pending', dequeued_at = NULL, deadline_at = NULL WHERE
      status = 'running' AND deadline_at < now() at time zone 'utc'
    """
  end

  def reserve(ids) do
    """
    UPDATE $TABLE$ SET
     status = 'running',
     dequeued_at = now() at time zone 'utc',
     deadline_at = now() at time zone 'utc' + ($TABLE$.max_runtime_seconds::text || ' ' || 'seconds'::text)::interval
    WHERE id in (#{ids})
    AND dequeued_at IS NULL
    RETURNING *
    """
  end

  def retry do
    """
    UPDATE $TABLE$ SET
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
    "SELECT * from $TABLE$ where status = 'dead' limit $1"
  end

  def purge do
    "DELETE FROM $TABLE$"
  end

  def dead_purge do
    "DELETE FROM $TABLE$ where status = 'dead'"
  end

  def info do
    """
    select
    (select count(*) from $TABLE$ where status = 'pending' AND scheduled_at IS NULL) as pending,
    (select count(*) from $TABLE$ where status = 'pending' AND scheduled_at IS NOT NULL) as delayed,
    (select count(*) from $TABLE$ where status = 'running') as running,
    (select count(*) from $TABLE$ where status = 'dead') as dead;
    """
  end
end
