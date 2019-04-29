defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case
  alias LogflareLogger.{HttpBackend, Formatter}
  alias Jason, as: JSON
  require Logger

  @host "127.0.0.1"

  @logger_backend {LogflareLogger.Backend, :test}
  Logger.add_backend(@logger_backend)

  @default_config [
    host: @host,
    port: nil,
    format: {Formatter, :format},
    level: :info,
    max_batch_size: 10,
    type: "testing",
    metadata: []
  ]

  setup do
    bypass = Bypass.open()

    config = build_config(@default_config, port: bypass.port)

    :ok = Logger.configure_backend(@logger_backend, config)

    {:ok, bypass: bypass, config: config}
  end

  test "logger backend sends a POST request", %{bypass: bypass} do
    log_msg = "Incoming log from test"

    Bypass.expect_once(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert [
               %{
                 "level" => "info",
                 "message" => "Incoming log from test #1",
                 "metadata" => %{},
                 "timestamp" => _
               }
               | _
             ] = JSON.decode!(body)

      Plug.Conn.resp(conn, 200, "")
    end)

    for n <- 1..10, do: Logger.info(log_msg <> " ##{n}")

    Logger.flush()
  end

  test "doesn't POST log events with a lower level", %{bypass: _bypass} do
    log_msg = "Incoming log from test"

    :ok = Logger.debug(log_msg)
    Process.sleep(100)
  end

  @msg "Incoming log from test with all metadata"
  test "correctly handles metadata keys", %{bypass: bypass, config: config} do

    Bypass.expect_once(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert [
               %{
                 "level" => "info",
                 "message" => @msg,
                 "metadata" => %{
                   "pid" => pidbinary,
                   "module" => _,
                   "file" => _,
                   "line" => _,
                   "function" => _
                 },
                 "timestamp" => _
               }
               | _
             ] = JSON.decode!(body)

      assert is_binary(pidbinary)

      Plug.Conn.resp(conn, 200, "")
    end)

    log_msg = @msg

    config =
      build_config(config,
        metadata: :all
      )

    :ok = Logger.configure_backend(@logger_backend, config)

    :ok = Logger.info(log_msg)
    Logger.flush()
  end

  def build_config(config, opts) do
    Keyword.merge(config, opts)
  end
end
