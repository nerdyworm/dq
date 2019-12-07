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

    plug(CORSPlug, headers: ["*"])
    plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
    plug(:auth)
    plug(:match)
    plug(:dispatch)

    def init(opts) do
      opts
    end

    def auth(conn, _opts) do
      incoming = get_req_header(conn, "authorization")
      token = Application.get_env(:dq, :token, "")

      if "#{incoming}" == "#{token}" do
        conn
      else
        conn
        |> send_resp(403, "Invalid DQ token")
        |> halt
      end
    end

    get "/api/queues" do
      queues = Application.get_env(:dq, :queues, [])

      data =
        Enum.map(queues, fn
          [source: queue, dest: _] ->
            {:ok, info} = queue.info()
            render_queue(queue, info)

          queue ->
            {:ok, info} = queue.info()
            render_queue(queue, info)
        end)

      json(conn, 200, data)
    end

    get "/api/queues/:name" do
      queue = name |> String.to_existing_atom()
      {:ok, info} = queue.info()
      data = render_queue(queue, info)
      json(conn, 200, data)
    end

    get "/api/queues/:name/pop" do
      queue = name |> String.to_existing_atom()
      {:ok, dead} = queue.pop(10)
      jobs = Enum.map(dead, &render_job(queue, &1))
      json(conn, 200, jobs)
    end

    put "/api/queues/:name/purge" do
      queue = name |> String.to_existing_atom()
      :ok = queue.purge()

      conn
      |> send_resp(204, "")
      |> halt
    end

    put "/api/jobs/move" do
      # dest_queue = conn.params["dest"] |> String.to_atom()

      Enum.each(conn.params["jobs"], fn params ->
        source_queue = params["queue"] |> String.to_atom()
        job = source_queue.decode(params["encoded"])

        dest_queue = dest(source_queue)
        :ok = dest_queue.push(job)
        :ok = source_queue.ack(job)
      end)

      conn
      |> send_resp(204, "")
      |> halt
    end

    put "/api/jobs/ack" do
      Enum.each(conn.params["jobs"], fn params ->
        queue = params["queue"] |> String.to_atom()
        job = queue.decode(params["encoded"])
        :ok = queue.ack(job)
      end)

      conn
      |> send_resp(204, "")
      |> halt
    end

    def dest(source) do
      queues = Application.get_env(:dq, :queues, [])

      Enum.find_value(queues, fn
        [source: ^source, dest: dest] ->
          dest

        _ ->
          nil
      end)
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
        args: job.args |> render_args(),
        status: to_string(job.status),
        error_count: job.error_count,
        error_message: to_string(job.error_message),
        encoded: queue.encode(job)
      }
    end

    def render_args(args) do
      Poison.encode!(args, pretty: true)
    end
  end
end
