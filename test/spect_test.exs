defmodule Spect.Test do
  use ExUnit.Case, async: true

  import ExUnit.Assertions
  import Spect

  alias Spect.ConvertError
  alias Spect.Support.Specs
  alias Spect.Support.Specs.{AdvancedStruct, BasicStruct}

  test "invalid spec" do
    assert_raise(ArgumentError, ~r/^module not found:/, fn ->
      to_spec!(%{}, Invalid.Module)
    end)

    assert_raise(ArgumentError, ~r/^type not found:/, fn ->
      to_spec!("str", String, :t2)
    end)
  end

  test "literals" do
    assert to_spec(:atom, Specs, :literal_atom) === {:ok, :atom}
    assert to_spec("atom", Specs, :literal_atom) === {:ok, :atom}
    {:error, %ConvertError{}} = to_spec(:mota, Specs, :literal_atom)
    {:error, %ConvertError{}} = to_spec("not an atom", Specs, :literal_atom)

    assert to_spec(nil, Specs, :literal_nil) === {:ok, nil}
    {:error, %ConvertError{}} = to_spec(1, Specs, :literal_nil)
    assert to_spec(true, Specs, :literal_true) === {:ok, true}
    assert to_spec("true", Specs, :literal_true) === {:ok, true}
    {:error, %ConvertError{}} = to_spec(false, Specs, :literal_true)
    assert to_spec(false, Specs, :literal_false) === {:ok, false}
    assert to_spec("false", Specs, :literal_false) === {:ok, false}
    {:error, %ConvertError{}} = to_spec(true, Specs, :literal_false)

    assert to_spec(1, Specs, :literal_1) === {:ok, 1}
    {:error, %ConvertError{}} = to_spec(2, Specs, :literal_1)

    assert to_spec([], Specs, :literal_list) === {:ok, []}
    {:error, %ConvertError{}} = to_spec(1, Specs, :literal_list)

    assert to_spec(%{}, Specs, :literal_map) == {:ok, %{}}
    {:error, %ConvertError{}} = to_spec(1, Specs, :literal_map)
  end

  test "basic types" do
    assert to_spec(nil, Specs, :basic_any) === {:ok, nil}
    assert to_spec(42, Specs, :basic_any) === {:ok, 42}

    {:error, %ConvertError{}} = to_spec(nil, Specs, :basic_none)
    {:error, %ConvertError{}} = to_spec(42, Specs, :basic_none)

    assert to_spec(nil, Specs, :basic_atom) === {:ok, nil}
    assert to_spec(:atom, Specs, :basic_atom) === {:ok, :atom}
    assert to_spec("atom", Specs, :basic_atom) === {:ok, :atom}
    {:error, %ConvertError{}} = to_spec(42, Specs, :basic_atom)

    assert to_spec(true, Specs, :basic_boolean) === {:ok, true}
    assert to_spec(false, Specs, :basic_boolean) === {:ok, false}
    {:error, %ConvertError{}} = to_spec(nil, Specs, :basic_boolean)

    assert to_spec(1, Specs, :basic_integer) === {:ok, 1}
    {:error, %ConvertError{}} = to_spec("invalid", Specs, :basic_integer)

    assert to_spec(1.0, Specs, :basic_float) === {:ok, 1.0}
    assert to_spec(1, Specs, :basic_float) === {:ok, 1.0}
    {:error, %ConvertError{}} = to_spec("1", Specs, :basic_float)

    assert to_spec(1.0, Specs, :basic_number) === {:ok, 1.0}
    assert to_spec(1, Specs, :basic_number) === {:ok, 1}
    {:error, %ConvertError{}} = to_spec("2", Specs, :basic_number)

    assert to_spec(-1, Specs, :basic_neg_integer) === {:ok, -1}
    {:error, %ConvertError{}} = to_spec(0, Specs, :basic_neg_integer)
    {:error, %ConvertError{}} = to_spec(1, Specs, :basic_neg_integer)
    {:error, %ConvertError{}} = to_spec("-2", Specs, :basic_neg_integer)

    assert to_spec(0, Specs, :basic_non_neg_integer) === {:ok, 0}
    assert to_spec(1, Specs, :basic_non_neg_integer) === {:ok, 1}
    {:error, %ConvertError{}} = to_spec("2", Specs, :basic_non_neg_integer)
    {:error, %ConvertError{}} = to_spec(-1, Specs, :basic_non_neg_integer)

    assert to_spec(1, Specs, :basic_pos_integer) === {:ok, 1}
    {:error, %ConvertError{}} = to_spec(0, Specs, :basic_pos_integer)
    {:error, %ConvertError{}} = to_spec("2", Specs, :basic_pos_integer)
    {:error, %ConvertError{}} = to_spec(-1, Specs, :basic_pos_integer)

    assert to_spec(%{}, Specs, :basic_struct) === {:ok, %{}}
    {:error, %ConvertError{}} = to_spec(1, Specs, :basic_struct)

    assert to_spec("str", String) === {:ok, "str"}
    {:error, %ConvertError{}} = to_spec(1, String)

    assert to_spec({}, Specs, :basic_tuple) === {:ok, {}}
    assert to_spec({1, 2}, Specs, :basic_tuple) === {:ok, {1, 2}}
    assert to_spec([1, 2], Specs, :basic_tuple) === {:ok, {1, 2}}
    {:error, %ConvertError{}} = to_spec(%{}, Specs, :basic_tuple)

    assert to_spec([], Specs, :basic_list) === {:ok, []}
    assert to_spec([1, 2], Specs, :basic_list) === {:ok, [1, 2]}
    {:error, %ConvertError{}} = to_spec(42, Specs, :basic_list)

    assert to_spec(%{}, Specs, :basic_map) === {:ok, %{}}
    assert to_spec(%{"1" => 1}, Specs, :basic_map) === {:ok, %{"1" => 1}}
    {:error, %ConvertError{}} = to_spec([{1, 2}], Specs, :basic_map)
  end

  test "union types" do
    assert to_spec(1, Specs, :union_12) === {:ok, 1}
    assert to_spec(2, Specs, :union_12) === {:ok, 2}
    {:error, %ConvertError{}} = to_spec(3, Specs, :union_12)

    assert to_spec(:atom, Specs, :union_atom_str) === {:ok, :atom}
    assert to_spec("atom", Specs, :union_atom_str) === {:ok, :atom}
    {:error, %ConvertError{}} = to_spec(42, Specs, :union_atom_str)

    assert to_spec("not an atom", Specs, :union_atom_str) ===
             {:ok, "not an atom"}

    assert to_spec({1}, Specs, :union_tuple_list) === {:ok, {1}}
    assert to_spec([1, 2], Specs, :union_tuple_list) === {:ok, {1, 2}}
  end

  test "tuple types" do
    assert to_spec({:ok, 42, "str"}, Specs, :tuple_test) ===
             {:ok, {:ok, 42, "str"}}

    assert to_spec(["error", 1, "test"], Specs, :tuple_test) ===
             {:ok, {:error, 1, "test"}}

    {:error, %ConvertError{}} = to_spec({}, Specs, :tuple_test)
    {:error, %ConvertError{}} = to_spec({1, 2, 3}, Specs, :tuple_test)
  end

  test "list types" do
    assert to_spec([], Specs, :list_test) === {:ok, []}
    assert to_spec([1], Specs, :list_test) === {:ok, [1]}
    assert to_spec([1, 2], Specs, :list_test) === {:ok, [1, 2]}
    {:error, %ConvertError{}} = to_spec(1, Specs, :list_test)
  end

  test "struct types" do
    assert to_spec(%BasicStruct{}, Specs, :basic_struct) ===
             {:ok, %BasicStruct{}}

    assert to_spec(%{}, BasicStruct) === {:ok, %BasicStruct{}}
    assert to_spec(%BasicStruct{}, BasicStruct) === {:ok, %BasicStruct{}}

    assert to_spec(%BasicStruct{int: 2}, BasicStruct) ===
             {:ok, %BasicStruct{int: 2}}

    assert to_spec(%{int: 2}, BasicStruct) === {:ok, %BasicStruct{int: 2}}

    assert to_spec(%{"int" => 2}, BasicStruct) === {:ok, %BasicStruct{int: 2}}
    {:error, %ConvertError{}} = to_spec(1, BasicStruct)
  end

  test "map types" do
    assert to_spec(%{}, Specs, :map_test) === {:ok, %{}}
    assert to_spec(%{1 => "str"}, Specs, :map_test) === {:ok, %{1 => "str"}}

    assert to_spec(%{1 => "str", 2 => "str"}, Specs, :map_test) ===
             {:ok, %{1 => "str", 2 => "str"}}

    {:error, %ConvertError{}} = to_spec(1, Specs, :map_test)

    assert to_spec(%{}, Specs, :map_required_test) === {:ok, %{}}
    assert to_spec(%{ok: 1}, Specs, :map_required_test) === {:ok, %{ok: 1}}
    {:error, %ConvertError{}} = to_spec(1, Specs, :map_required_test)

    assert to_spec(%{:key1 => 1, "key2" => "str"}, Specs, :map_exact_test) ===
             {:ok, %{key1: 1, key2: "str"}}

    {:error, %ConvertError{}} = to_spec(1, Specs, :map_exact_test)
    {:error, %ConvertError{}} = to_spec(%{key1: 1}, Specs, :map_exact_test)
  end

  test "module type" do
    assert to_spec!("Elixir.Spect.Support.Specs", Specs, :module_test) ==
             Specs

    assert to_spec!(Specs, Specs, :module_test) == Specs
    {:error, %ConvertError{}} = to_spec("NonExistent", Specs, :module_test)
  end

  test "datetimes" do
    {:error, %ConvertError{}} = to_spec("non_dt_str", Specs, :datetime_test)

    {:error, %ConvertError{}} = to_spec(1, Specs, :datetime_test)

    now = DateTime.utc_now()
    expect = {:ok, now}

    assert to_spec(to_string(now), Specs, :datetime_test) == expect
    assert to_spec(now, Specs, :datetime_test) == expect
  end

  test "parameterized types" do
    assert to_spec(1234, Specs, :maybe_int) === {:ok, 1234}
    assert to_spec(nil, Specs, :maybe_int) === {:ok, nil}

    assert to_spec(%{test: "a"}, Specs.ParameterizedStruct) ===
             {:ok, %Specs.ParameterizedStruct{test: "a"}}
  end

  test "user_types" do
    now = DateTime.utc_now()

    input = %{
      "datetime" => now,
      "example" => "a",
      "basics" => [],
      "map" => %{},
      "tuple" => ["a", "b"]
    }

    expect = %AdvancedStruct{datetime: now, example: :a, basics: []}
    assert to_spec!(input, AdvancedStruct) == expect

    input = %{
      input
      | "basics" => [Map.from_struct(%BasicStruct{})],
        "map" => %{"c" => "d", "d" => "c"}
    }

    expect = %{expect | basics: [%BasicStruct{}], map: %{c: :d, d: :c}}
    assert to_spec!(input, AdvancedStruct) == expect
  end
end
