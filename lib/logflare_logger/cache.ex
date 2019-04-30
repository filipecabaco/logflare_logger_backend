defmodule LogflareLogger.Cache do
  @batch :batch
  @cache __MODULE__

  def add_event_to_batch(event, key \\ @batch) do
    Cachex.get_and_update!(@cache, key, &[event | &1 || []])
  end

  def get_batch(key \\ @batch) do
    @cache
    |> Cachex.get!(key)
    |> list_if_nil()
    |> Enum.reverse()
  end

  def reset_batch(key \\ @batch) do
    Cachex.put!(@cache, key, [])
  end

  def list_if_nil(nil), do: []
  def list_if_nil(xs), do: xs

end
