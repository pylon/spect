defmodule Spect do
  @moduledoc """
  Elixir typespec enhancements
  """

  use Memoize

  defmodule ConvertError do
    @moduledoc """
    A custom exception raised when a field could not be converted
    to the type declared by the target typespec.
    """
    defexception message: "could not map to spec"
  end

  @doc """
  Typespec-driven object decoding

  This function converts a data structure into a new one derived from a type
  specification. This provides for the effective decoding of (nested) data
  structures from serialization formats that do not support Elixir's rich set of
  types (JSON, etc.). Atoms can be decoded from strings, tuples from lists,
  structs from maps, etc.

  `data` is the data structure to decode, `module` is the name of the module
  containing the type specification, and `name` is the name of the @type
  definition within the module (defaults to `:t`).

  ## Examples

  As mentioned above, a common use case is to decode a JSON document into an
  Elixir struct, for example using the `Poison` parser:
    ```elixir
      "test.json"
      |> File.read!()
      |> Poison.Parser.parse!()
      |> Spect.to_spec!(Filmography)
    ```

  where the `Filmography` module might contain the following structs:
    ```elixir
      defmodule Filmography do

        defmodule Person do
          @type t :: %__MODULE__{
            name: String.t(),
            birth_year: pos_integer()
          }

          defstruct [:name, :birth_year]
        end

        @type acting_credit :: %{
            film: String.t(),
            lead?: boolean()
        }

        @type t :: %__MODULE__{
            subject: Person.t(),
            acting_credits: [acting_credit()]
        }

        defstruct [:subject, acting_credits: []]
      end
    ```

  The conventional name for a module's primary type is `t`, so that is the
  default value for `to_spec`'s third argument. However, that name is not
  mandatory, and modules can expose more than one type, so `to_spec` will accept
  any atom as a third argument and attempt to find a type with that name.
  Continuing with the above example:
    ```elixir
    iex> data = %{"film" => "Amadeus", "lead?" => true}
    %{"film" => "Amadeus", "lead?" => true}

    iex> Spect.to_spec(data, Filmography, :acting_credit)
    {:ok, %{film: "Amadeus", lead?: true}}
    ```

  If any of the nested fields in the typespec is declared as a `Date.t()`,
  `NaiveDateTime.t()`, or `DateTime.t()`, `to_spec` will convert the value only
  if it is an [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) string or
  already a `Date` / `NaiveDateTime` / `DateTime` struct.
  """
  @spec to_spec(data :: any, module :: atom, name :: atom) ::
          {:ok, any} | {:error, any}
  def to_spec(data, module, name \\ :t) do
    {:ok, to_spec!(data, module, name)}
  rescue
    e -> {:error, e}
  end

  @doc """
  Decodes an object from a typespec, raising `ArgumentError` if the type
  is not found or `Spect.ConvertError` for a value error during conversion.
  """
  @spec to_spec!(data :: any, module :: atom, name :: atom, args :: list()) ::
          any
  def to_spec!(data, module, name \\ :t, args \\ []) do
    module
    |> load_types()
    |> Keyword.values()
    |> Enum.filter(fn {k, _v, _a} -> k == name end)
    |> case do
      [{^name, type, vars}] ->
        to_kind!(data, module, type, Enum.zip(vars, args) |> Map.new())

      _ ->
        raise ArgumentError, "type not found: #{module}.#{name}"
    end
  end

  @doc false
  defmemo load_types(module) do
    case Code.Typespec.fetch_types(module) do
      {:ok, types} -> types
      :error -> raise ArgumentError, "module not found: #{module}"
    end
  end

  # -------------------------------------------------------------------------
  # top-level kind demultiplexing
  # -------------------------------------------------------------------------

  defp to_kind!(data, module, {:type, _line, type, args}, params) do
    to_type!(data, module, type, args, params)
  end

  defp to_kind!(data, module, {:remote_type, _line, type}, _params) do
    [{:atom, _, remote_module}, {:atom, _, name}, args] = type

    cond do
      remote_module == Date and name == :t ->
        to_date!(data)

      remote_module == NaiveDateTime and name == :t ->
        to_naivedatetime!(data)

      remote_module == DateTime and name == :t ->
        to_datetime!(data)

      true ->
        params = Enum.map(args, &{module, &1})
        to_spec!(data, remote_module, name, params)
    end
  end

  defp to_kind!(
         data,
         module,
         {:ann_type, _line, [{:var, _, _name}, type]},
         params
       ) do
    to_kind!(data, module, type, params)
  end

  defp to_kind!(data, module, {:user_type, _line, name, args}, _params) do
    params = Enum.map(args, &{module, &1})
    to_spec!(data, module, name, params)
  end

  defp to_kind!(data, _module, {:var, _line, _value} = var, params) do
    {module, type} = Map.fetch!(params, var)
    to_kind!(data, module, type, params)
  end

  defp to_kind!(data, _module, {kind, _line, value}, _params) do
    to_lit!(data, kind, value)
  end

  # -------------------------------------------------------------------------
  # literals
  # -------------------------------------------------------------------------

  # string->atom
  defp to_lit!(data, :atom, value) when is_binary(data) do
    ^value = String.to_existing_atom(data)
  rescue
    _ -> reraise(ConvertError, "invalid atom: #{value}", __STACKTRACE__)
  end

  # atom/bool/integer literal
  defp to_lit!(data, _kind, value) do
    if data === value do
      value
    else
      raise(ConvertError, "expected: #{value}, found: #{inspect(data)}")
    end
  end

  # -------------------------------------------------------------------------
  # types
  # -------------------------------------------------------------------------

  # any type
  defp to_type!(data, _module, :any, _args, _params) do
    data
  end

  # none type
  defp to_type!(_data, _module, :none, _args, _params) do
    raise ConvertError
  end

  # atom
  defp to_type!(data, _module, :atom, _args, _params) do
    cond do
      is_atom(data) -> data
      is_binary(data) -> String.to_existing_atom(data)
      true -> raise ArgumentError
    end
  rescue
    _ ->
      reraise(ConvertError, "invalid atom: #{inspect(data)}", __STACKTRACE__)
  end

  defp to_type!(data, module, :module, _args, params) do
    to_type!(data, module, :atom, [], params)
  end

  # boolean
  defp to_type!(data, _module, :boolean, _args, _params) do
    if is_boolean(data) do
      data
    else
      raise(ConvertError, "expected: boolean, found: #{inspect(data)}")
    end
  end

  # integer
  defp to_type!(data, _module, :integer, _args, _params) do
    if is_integer(data) do
      data
    else
      raise(ConvertError, "expected: integer, found: #{inspect(data)}")
    end
  end

  # float
  defp to_type!(data, _module, :float, _args, _params) do
    cond do
      is_float(data) -> data
      is_integer(data) -> data / 1.0
      true -> raise(ConvertError, "expected: float, found: #{inspect(data)}")
    end
  end

  # number
  defp to_type!(data, _module, :number, _args, _params) do
    if is_number(data) do
      data
    else
      raise(ConvertError, "expected: number, found: #{inspect(data)}")
    end
  end

  # negative integer
  defp to_type!(data, _module, :neg_integer, _args, _params) do
    if is_integer(data) and data < 0 do
      data
    else
      raise(
        ConvertError,
        "expected: negative integer, found: #{inspect(data)}"
      )
    end
  end

  # non-negative integer
  defp to_type!(data, _module, :non_neg_integer, _args, _params) do
    if is_integer(data) and data >= 0 do
      data
    else
      raise(
        ConvertError,
        "expected: non-negative integer, found: #{inspect(data)}"
      )
    end
  end

  # positive integer
  defp to_type!(data, _module, :pos_integer, _args, _params) do
    if is_integer(data) and data > 0 do
      data
    else
      raise(
        ConvertError,
        "expected: positive integer, found: #{inspect(data)}"
      )
    end
  end

  # string
  defp to_type!(data, _module, :binary, _args, _params) do
    if is_binary(data) do
      data
    else
      raise(ConvertError, "expected: string, found: #{inspect(data)}")
    end
  end

  # union a | b | c, return the first match, recursive
  defp to_type!(data, module, :union, types, params) do
    result =
      Enum.reduce_while(types, ConvertError, fn type, result ->
        try do
          {:halt, to_kind!(data, module, type, params)}
        rescue
          _ -> {:cont, result}
        end
      end)

    with ConvertError <- result do
      raise ConvertError,
            "expected: union of #{inspect(types)}, found: #{inspect(data)}"
    end
  end

  # tuple
  defp to_type!(data, module, :tuple, args, params) do
    to_tuple!(data, module, args, params)
  end

  # list
  defp to_type!(data, module, :list, args, params) do
    to_list!(data, module, args, params)
  end

  # empty list
  defp to_type!(data, _module, nil, [], _params) do
    if is_list(data) do
      data
    else
      raise(ConvertError, "expected: list, found: #{inspect(data)}")
    end
  end

  # map
  defp to_type!(data, module, :map, args, params) do
    to_map!(data, module, args, params)
  end

  # -------------------------------------------------------------------------
  # tuple types
  # -------------------------------------------------------------------------

  # any tuple, list->tuple
  defp to_tuple!(data, _module, :any, _params) do
    cond do
      is_tuple(data) -> data
      is_list(data) -> List.to_tuple(data)
      true -> raise(ConvertError, "expected: tuple, found: #{inspect(data)}")
    end
  end

  # exact tuple, list->tuple, recursive
  defp to_tuple!(data, module, types, params) do
    cond do
      is_tuple(data) ->
        to_tuple!(Tuple.to_list(data), module, types, params)

      is_list(data) and length(data) === length(types) ->
        Enum.reduce(Enum.zip(data, types), {}, fn {data, type}, result ->
          Tuple.append(result, to_kind!(data, module, type, params))
        end)

      true ->
        raise(ConvertError, "expected: tuple, found: #{inspect(data)}")
    end
  end

  # -------------------------------------------------------------------------
  # list types
  # -------------------------------------------------------------------------

  # typed list, recursive
  defp to_list!(data, module, [type], params) do
    if is_list(data) do
      Enum.map(data, &to_kind!(&1, module, type, params))
    else
      raise(ConvertError, "expected: list, found: #{inspect(data)}")
    end
  end

  # any list
  defp to_list!(data, _module, [], _params) do
    if is_list(data) do
      data
    else
      raise(ConvertError, "expected: list, found: #{inspect(data)}")
    end
  end

  # -------------------------------------------------------------------------
  # map types
  # -------------------------------------------------------------------------

  # any map -> struct-like map
  defp to_map!(
         data,
         _module,
         [
           {:type, _, :map_field_exact,
            [{:atom, _, :__struct__}, {:type, _, :atom, []}]}
           | _fields
         ],
         _params
       ) do
    if is_map(data) do
      Map.new(Map.to_list(data), fn
        {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
        {k, v} -> {k, v}
      end)
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # any map -> exact struct, recursive
  defp to_map!(
         data,
         module,
         [
           {:type, _, :map_field_exact,
            [{:atom, _, :__struct__}, {:atom, _, struct}]}
           | fields
         ],
         params
       ) do
    if is_map(data) do
      Enum.reduce(fields, Kernel.struct(struct), fn field, result ->
        {:type, _line, :map_field_exact, [{:atom, _, k}, type]} = field

        if Map.has_key?(data, k) do
          Map.put(result, k, to_kind!(Map.get(data, k), module, type, params))
        else
          sk = to_string(k)

          if Map.has_key?(data, sk) do
            Map.put(
              result,
              k,
              to_kind!(Map.get(data, sk), module, type, params)
            )
          else
            result
          end
        end
      end)
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # empty map
  defp to_map!(data, _module, [], _params) do
    if is_map(data) do
      data
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # any map
  defp to_map!(data, _module, :any, _params) do
    if is_map(data) do
      data
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # any typed map, recursive
  defp to_map!(
         data,
         module,
         [{:type, _line, _mode, [key_field, val_field]}],
         params
       )
       when elem(key_field, 0) in [
              :type,
              :remote_type,
              :ann_type,
              :user_type
            ] do
    if is_map(data) do
      Enum.reduce(Map.to_list(data), %{}, fn {k, v}, r ->
        Map.put(
          r,
          to_kind!(k, module, key_field, params),
          to_kind!(v, module, val_field, params)
        )
      end)
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # any map, exact keys, recursive
  defp to_map!(data, module, fields, params) do
    if is_map(data) do
      Enum.reduce(fields, %{}, fn field, result ->
        {:type, _line, mode, [{_, _, k}, type]} = field

        if Map.has_key?(data, k) do
          Map.put(result, k, to_kind!(Map.get(data, k), module, type, params))
        else
          sk = to_string(k)

          if Map.has_key?(data, sk) do
            Map.put(
              result,
              k,
              to_kind!(Map.get(data, sk), module, type, params)
            )
          else
            if mode == :map_field_exact do
              raise(
                ConvertError,
                "missing map required key: #{k} in #{inspect(data)}"
              )
            end

            result
          end
        end
      end)
    else
      raise(ConvertError, "expected: map, found: #{inspect(data)}")
    end
  end

  # -------------------------------------------------------------------------
  # miscellaneous types
  # -------------------------------------------------------------------------

  defp to_date!(data) do
    cond do
      is_binary(data) ->
        case Date.from_iso8601(data) do
          {:ok, dt} ->
            dt

          {:error, reason} ->
            raise(
              ConvertError,
              "invalid string format for Date: #{reason}"
            )
        end

      is_map(data) and data.__struct__ == Date ->
        data

      true ->
        raise(
          ConvertError,
          "expected ISO8601 string or Date struct, found: #{inspect(data)}"
        )
    end
  end

  defp to_naivedatetime!(data) do
    cond do
      is_binary(data) ->
        case NaiveDateTime.from_iso8601(data) do
          {:ok, dt} ->
            dt

          {:error, reason} ->
            raise(
              ConvertError,
              "invalid string format for NaiveDateTime: #{reason}"
            )
        end

      is_map(data) and data.__struct__ == NaiveDateTime ->
        data

      true ->
        raise(
          ConvertError,
          "expected ISO8601 string or NaiveDateTime struct, found: #{inspect(data)}"
        )
    end
  end

  defp to_datetime!(data) do
    cond do
      is_binary(data) ->
        case DateTime.from_iso8601(data) do
          {:ok, dt, _utc_offset} ->
            dt

          {:error, reason} ->
            raise(
              ConvertError,
              "invalid string format for DateTime: #{reason}"
            )
        end

      is_map(data) and data.__struct__ == DateTime ->
        data

      true ->
        raise(
          ConvertError,
          "expected ISO8601 string or DateTime struct, found: #{inspect(data)}"
        )
    end
  end
end
