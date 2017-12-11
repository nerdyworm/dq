defmodule DQ.Plug do
  alias DQ.Plug.Router

  def init(options) do
    options
  end

  def call(conn, opts) do
    namespace = opts[:namespace] || "dq"
    Plug.Conn.assign(conn, :namespace, namespace)
    |> namespace(opts, namespace)
  end

  def namespace(%Plug.Conn{path_info: [ns | path]} = conn, opts, ns) do
    Router.call(%Plug.Conn{conn | path_info: path}, Router.init(opts))
  end

  defmodule Router do
    use Plug.Router

    plug CORSPlug, headers: ["*"]
    plug Plug.Parsers, parsers: [:json], json_decoder: Poison
    plug :auth
    plug :match
    plug :dispatch

    def init(opts) do
      opts
    end

    def auth(conn, _opts) do
      incoming = get_req_header(conn, "x-dq-authorization")
      token    = Application.get_env(:dq, :token, "")
      # if "#{incoming}" == "#{token}" do
        conn
      # else
      #   conn
      #   |> send_resp(403, "Invalid token")
      #   |> halt
      # end
    end

    get "/api/ping" do
      conn
      |> send_resp(200, "ok")
      |> halt
    end

    get "/api/queues" do
      queues = Application.get_env(:dq, :queues, [])
      data =
        Enum.map(queues, fn(queue) ->
          {:ok, info} = queue.info()
          render_queue(queue, info)
        end)

      json(conn, 200, data)
    end

    get "/api/queues/:name" do
      queue = name |> String.to_existing_atom
      {:ok, info} = queue.info
      data = render_queue(queue, info)
      json(conn, 200, data)
    end

    put "/api/queues/:name/dead_purge" do
      queue = name |> String.to_existing_atom
      :ok = queue.dead_purge

      conn
      |> send_resp(204, "")
      |> halt
    end

    put "/api/jobs/retry" do
      queue = conn.params["queue"] |> String.to_atom
      job = queue.decode(conn.params["encoded"])
      :ok = queue.dead_retry(job)

      conn
      |> send_resp(204, "")
      |> halt
    end

    put "/api/jobs/ack" do
      queue = conn.params["queue"] |> String.to_atom
      job = queue.decode(conn.params["encoded"])
      :ok = queue.dead_ack(job)

      conn
      |> send_resp(204, "")
      |> halt
    end

    get "/api/queues/:name/dead" do
      queue = name |> String.to_existing_atom
      {:ok, dead} = queue.dead
      jobs = Enum.map(dead, &(render_job(queue, &1)))
      json(conn, 200, jobs)
    end


    def json(conn, code, body) do
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(code, Poison.encode!(body))
      |> halt
    end

    def render_queue(queue, info) do
      Map.delete(info, :__struct__)
      |> Map.merge(%{name: "#{queue}"})
    end

    def render_job(queue, job) do
      %{
        id: job.id,
        queue: "#{queue}",
        module: job.module,
        args: job.args,
        status: job.status,
        error_count: job.error_count,
        error_message: job.error_message,
        encoded: queue.encode(job)
      }
    end
  end
end
