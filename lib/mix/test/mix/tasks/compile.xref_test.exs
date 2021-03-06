Code.require_file("../../test_helper.exs", __DIR__)

defmodule Mix.Tasks.Compile.XrefTest do
  use MixTest.Case

  import ExUnit.CaptureIO

  setup do
    Mix.Project.push(MixTest.Case.Sample)
    :ok
  end

  test "doesn't xref if not stale, unless forced" do
    in_fixture("no_mixfile", fn ->
      write_deprecated_func()

      assert_warn(fn ->
        assert Mix.Tasks.Compile.Elixir.run([]) == {:ok, []}
        assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run([])
      end)

      assert_no_warn(fn -> assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run([]) end)
      assert_warn(fn -> assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run(["--force"]) end)
    end)
  end

  test "doesn't xref if not stale, unless all warnings" do
    in_fixture("no_mixfile", fn ->
      write_deprecated_func()

      assert_warn(fn ->
        assert Mix.Tasks.Compile.Elixir.run([]) == {:ok, []}
        assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run([])
      end)

      assert_no_warn(fn -> assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run([]) end)

      assert_warn(fn ->
        assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run(["--all-warnings"])
      end)
    end)
  end

  test "xrefs if stale" do
    in_fixture("no_mixfile", fn ->
      write_deprecated_func()

      assert_warn(fn ->
        assert Mix.Tasks.Compile.Elixir.run([]) == {:ok, []}
        file = Path.absname("lib/a.ex")

        assert {:noop, [diagnostic]} = Mix.Tasks.Compile.Xref.run([])

        assert %Mix.Task.Compiler.Diagnostic{
                 compiler_name: "Xref",
                 file: ^file,
                 message: "B.deprecated_func/0 is deprecated. message",
                 position: 2,
                 severity: :warning
               } = diagnostic
      end)

      [manifest] = Mix.Tasks.Compile.Elixir.manifests()
      future = {{2038, 1, 1}, {0, 0, 0}}
      File.touch!(manifest, future)

      Mix.Task.reenable("xref")

      assert_warn(fn -> assert {:noop, [_]} = Mix.Tasks.Compile.Xref.run([]) end)
    end)
  end

  test "exits if --warnings-as-errors" do
    in_fixture("no_mixfile", fn ->
      write_deprecated_func()

      assert_warn(fn ->
        assert Mix.Tasks.Compile.Elixir.run([]) == {:ok, []}
        assert {:error, [diagnostic]} = Mix.Tasks.Compile.Xref.run(["--warnings-as-errors"])
        assert %Mix.Task.Compiler.Diagnostic{severity: :error} = diagnostic
      end)
    end)
  end

  test "does not exit if --warnings-as-errors and no warnings" do
    in_fixture("no_mixfile", fn ->
      assert_no_warn(fn ->
        assert Mix.Tasks.Compile.Elixir.run([]) == {:ok, []}
        assert Mix.Tasks.Compile.Xref.run(["--warnings-as-errors"]) == {:noop, []}
      end)
    end)
  end

  defp write_deprecated_func do
    File.write!("lib/a.ex", """
    defmodule A do
      def a, do: B.deprecated_func
    end
    """)

    File.write!("lib/b.ex", """
    defmodule B do
      @deprecated "message"
      def deprecated_func, do: :ok
    end
    """)
  end

  defp assert_warn(fun) do
    assert capture_io(:stderr, fun) =~ "deprecated_func"
  end

  defp assert_no_warn(fun) do
    assert capture_io(:stderr, fun) == ""
  end
end
