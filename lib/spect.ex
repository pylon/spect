defmodule Spect do
  @moduledoc """
  elixir typespec enhancements
  """

  alias Kernel.Typespec

  defmodule ConvertError do
    defexception message: nil
  end

  @doc """
  typespec-driven object decoding

  This function converts a data structure into a new one derived from a type
  specification. This provides for the effective decoding of (nested) data
  structures from serialization formats that do not support Elixir's rich
  set of types (json, etc.). Atoms can be decoded from strings, tuples from
  lists, structs from maps, etc.

  `data` is the data structure to decode, `module` is the name of the module
  containing the type specification, and `name` is the name of the @type
  definition within the module (defaults to `:t`).

  As mentioned above, a common use case is to decode a JSON document into
  an Elixir struct, for example using the poison parser:
    ```elixir
      "test.json"
      |> File.read!()
      |> Poison.Parser.parse!()
      |> Spect.to_spec!(My.Master)
    ```

  where the `My` module might contain the following structs:
    ```elixir
      defmodule My do
        defmodule Master do
          @type t :: %__MODULE__{
            rest: integer(),
            details: %{String.t() => My.Detail.t()}
          }
          defstruct [rest: 2, details: %{}]
        end

        defmodule Detail do
          @type t :: %__MODULE__{
            nest: integer()
          }
          defstruct [nest: 1]
        end
      end
    ```
  """
  @spec to_spec(data :: any, module :: atom, name :: atom) ::
          {:ok, any} | {:error, any}
  def to_spec(data, module, name \\ :t) do
    {:ok, to_spec!(data, module, name)}
  rescue
    e -> {:error, e}
  end

  @doc """
  decodes an object from a typespec, raising on error
  """
  @spec to_spec!(data :: any, module :: atom, name :: atom) :: any
  def to_spec!(data, module, name \\ :t) do
    types = Typespec.beam_types(module)

    if types === nil do
      raise ArgumentError, "module not found: #{module}"
    end

    types
    |> Keyword.values()
    |> Enum.filter(fn {k, _v, _a} -> k == name end)
    |> case do
      [{^name, type, _args}] -> to_type!(data, type)
      _ -> raise ArgumentError, "type not found: #{module}.#{name}"
    end
  end

  # -------------------------------------------------------------------------
  # literals
  # -------------------------------------------------------------------------

  # string->atom
  defp to_type!(data, {:atom, _line, value} = type) when is_binary(data) do
    ^value = String.to_existing_atom(data)
  rescue
    _ -> reraise(ConvertError, inspect(type), System.stacktrace())
  end

  # atom/bool/integer literal
  defp to_type!(data, {kind, _line, value} = type)
       when kind in [:atom, :boolean, :integer] do
    if data === value do
      value
    else
      raise(ConvertError, inspect(type))
    end
  end

  # empty list literal
  defp to_type!(data, {:type, _line, nil, []}) when is_list(data) do
    data
  end

  # empty map literal
  defp to_type!(data, {:type, _line, :map, []}) when is_map(data) do
    data
  end

  # -------------------------------------------------------------------------
  # basic types
  # -------------------------------------------------------------------------

  # any type
  defp to_type!(data, {:type, _line, :any, []}) do
    data
  end

  # none type
  defp to_type!(_data, {:type, _line, :none, []} = type) do
    raise(ConvertError, inspect(type))
  end

  # atoms
  defp to_type!(data, {:type, _line, :atom, []}) when is_atom(data) do
    data
  end

  # string->atom
  defp to_type!(data, {:type, _line, :atom, []} = type) when is_binary(data) do
    String.to_existing_atom(data)
  rescue
    _ -> reraise(ConvertError, inspect(type), System.stacktrace())
  end

  # boolean
  defp to_type!(data, {:type, _line, :boolean, []}) when is_boolean(data) do
    data
  end

  # integer
  defp to_type!(data, {:type, _line, :integer, []}) when is_integer(data) do
    data
  end

  # float
  defp to_type!(data, {:type, _line, :float, []}) when is_float(data) do
    data
  end

  # number
  defp to_type!(data, {:type, _line, :number, []}) when is_number(data) do
    data
  end

  # negative integer
  defp to_type!(data, {:type, _line, :neg_integer, []})
       when is_integer(data) and data < 0 do
    data
  end

  # non-negative integer
  defp to_type!(data, {:type, _line, :non_neg_integer, []})
       when is_integer(data) and data >= 0 do
    data
  end

  # positive integer
  defp to_type!(data, {:type, _line, :pos_integer, []})
       when is_integer(data) and data > 0 do
    data
  end

  # string
  defp to_type!(data, {:type, _line, :binary, []}) when is_binary(data) do
    data
  end

  # any tuple
  defp to_type!(data, {:type, _line, :tuple, :any}) when is_tuple(data) do
    data
  end

  # any list->tuple
  defp to_type!(data, {:type, _line, :tuple, :any}) when is_list(data) do
    Enum.reduce(data, {}, &Tuple.append(&2, &1))
  end

  # any list
  defp to_type!(data, {:type, _line, :list, []}) when is_list(data) do
    data
  end

  # any map
  defp to_type!(data, {:type, _line, :map, :any}) when is_map(data) do
    data
  end

  # -------------------------------------------------------------------------
  # union types
  # -------------------------------------------------------------------------

  # a | b | c, return the first match, recursive
  defp to_type!(data, {:type, _line, :union, types} = type) do
    results =
      types
      |> Enum.map(fn type ->
        try do
          to_type!(data, type)
        rescue
          _ -> ConvertError
        end
      end)
      |> Enum.filter(fn result -> result !== ConvertError end)

    case results do
      [result | _results] -> result
      _ -> raise ConvertError, inspect(type)
    end
  end

  # -------------------------------------------------------------------------
  # tuple types
  # -------------------------------------------------------------------------

  # exact tuple, recursive
  defp to_type!(data, {:type, line, :tuple, types}) when is_tuple(data) do
    to_type!(Tuple.to_list(data), {:type, line, :tuple, types})
  end

  # exact list->tuple, recursive
  defp to_type!(data, {:type, _line, :tuple, types})
       when is_list(data) and length(data) === length(types) do
    Enum.reduce(Enum.zip(data, types), {}, fn {data, type}, result ->
      Tuple.append(result, to_type!(data, type))
    end)
  end

  # -------------------------------------------------------------------------
  # list types
  # -------------------------------------------------------------------------

  # typed list, recursive
  defp to_type!(data, {:type, _line, :list, [type]}) when is_list(data) do
    Enum.map(data, &to_type!(&1, type))
  end

  # -------------------------------------------------------------------------
  # struct types
  # -------------------------------------------------------------------------

  # any map -> struct-like map
  defp to_type!(
         data,
         {:type, _line, :map,
          [
            {:type, _, :map_field_exact,
             [{:atom, _, :__struct__}, {:type, _, :atom, []}]}
            | _fields
          ]}
       )
       when is_map(data) do
    Map.new(Map.to_list(data), fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  # any map -> exact struct, recursive
  defp to_type!(
         data,
         {:type, _line, :map,
          [
            {:type, _, :map_field_exact,
             [{:atom, _, :__struct__}, {:atom, _, struct}]}
            | fields
          ]}
       )
       when is_map(data) do
    Enum.reduce(fields, Kernel.struct(struct), fn field, result ->
      {:type, _line, :map_field_exact, [{:atom, _, k}, type]} = field

      if Map.has_key?(data, k) do
        Map.put(result, k, to_type!(Map.get(data, k), type))
      else
        sk = to_string(k)

        if Map.has_key?(data, sk) do
          Map.put(result, k, to_type!(Map.get(data, sk), type))
        else
          result
        end
      end
    end)
  end

  # -------------------------------------------------------------------------
  # map types
  # -------------------------------------------------------------------------

  # any map, recursive
  defp to_type!(
         data,
         {:type, _line, :map, [{:type, _, mode, [key_field, val_field]}]}
       )
       when is_map(data) and mode in [:map_field_exact, :map_field_assoc] do
    Enum.reduce(Map.to_list(data), %{}, fn {k, v}, r ->
      Map.put(r, to_type!(k, key_field), to_type!(v, val_field))
    end)
  end

  # -------------------------------------------------------------------------
  # remote types
  # -------------------------------------------------------------------------

  # fetch remote, recursive to_spec
  defp to_type!(
         data,
         {:remote_type, _line, [{:atom, _, module}, {:atom, _, name}, []]}
       ) do
    to_spec!(data, module, name)
  end

  # -------------------------------------------------------------------------
  # default match
  # -------------------------------------------------------------------------

  defp to_type!(_data, type) do
    raise ConvertError, inspect(type)
  end
end
