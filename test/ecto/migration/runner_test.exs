defmodule Ecto.Migration.RunnerTest do
  use ExUnit.Case, async: false

  alias Ecto.Migration.Runner
  alias Ecto.Migration.Table
  alias Ecto.Migration.Index

  defmodule MockAdapter do
    def execute_migration(_repo, command) do
      {:migrated, command}
    end
  end

  defmodule MockRepo do
    def adapter do
      MockAdapter
    end
  end

  setup_all do
    {:ok, pid} = Runner.start_link(MockRepo)
    {:ok, pid: pid}
  end

  teardown_all context do
    :erlang.exit(context[:pid], :kill)
    :ok
  end

  test "run in forward direction" do
    Runner.direction(:up)

    assert Runner.execute({:create, Table.new, []}) == {:migrated, {:create, Table.new, []}}
    assert Runner.execute({:create, Index.new}) == {:migrated, {:create, Index.new}}
    assert Runner.execute({:drop, Table.new}) == {:migrated, {:drop, Table.new}}
    assert Runner.execute({:drop, Index.new}) == {:migrated, {:drop, Index.new}}
    assert Runner.execute({:alter, Table.new, []}) == {:migrated, {:alter, Table.new, []}}
  end

  test "run in reverse direction" do
    Runner.direction(:down)

    assert Runner.execute({:create, Table.new, []}) == {:migrated, {:drop, Table.new}}
    assert Runner.execute({:create, Index.new}) == {:migrated, {:drop, Index.new}}
    assert Runner.execute({:alter, Table.new, []}) == {:migrated, {:alter, Table.new, []}}
  end

  test "cannot reverse drop table" do
    Runner.direction(:down)

    assert Runner.execute({:drop, Table.new}) == :not_reversible
  end

  test "cannot reverse drop index" do
    Runner.direction(:down)

    assert Runner.execute({:drop, Index.new}) == :not_reversible
  end

  test "can reverse column additions to removals" do
    Runner.direction(:down)

    assert Runner.execute({:alter, Table.new, [{:add, :summary, :string, []}]}) == {:migrated, {:alter, Table.new, [{:remove, :summary}] }}
  end

  test "can reverse column renaming" do
    Runner.direction(:down)

    assert Runner.execute({:alter, Table.new, [{:rename, :summary, :details}]}) == {:migrated, {:alter, Table.new, [{:rename, :details, :summary}]}}
  end

  test "cannot reverse column removal" do
    Runner.direction(:down)

    assert Runner.execute({:alter, Table.new, [{:remove, :summary}]}) == :not_reversible
  end

  test "cannot reverse column modification" do
    Runner.direction(:down)

    assert Runner.execute({:alter, Table.new, [{:modify, :summary, :string, []}]}) == :not_reversible
  end
end