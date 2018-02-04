defmodule Spect.Support.Specs do
  @type literal_atom :: :atom
  @type literal_nil :: nil
  @type literal_true :: true
  @type literal_false :: false
  @type literal_1 :: 1
  @type literal_list :: []
  @type literal_map :: %{}

  @type basic_any :: any()
  @type basic_none :: none()
  @type basic_atom :: atom()
  @type basic_boolean :: boolean()
  @type basic_integer :: integer()
  @type basic_float :: float()
  @type basic_number :: number()
  @type basic_neg_integer :: neg_integer()
  @type basic_non_neg_integer :: non_neg_integer()
  @type basic_pos_integer :: pos_integer()
  @type basic_tuple :: tuple()
  @type basic_list :: list()
  @type basic_map :: map()
  @type basic_struct :: struct()

  @type union_12 :: 1 | 2
  @type union_atom_str :: atom() | String.t()
  @type union_tuple_list :: tuple() | list()

  @type tuple_test :: {atom(), integer(), String.t()}

  @type list_test :: [integer()]

  @type map_test :: %{integer() => String.t()}
  @type map_required_test :: %{required(atom()) => integer}

  defmodule BasicStruct do
    @type t :: %__MODULE__{
            atom: atom(),
            bool: boolean(),
            int: integer(),
            str: String.t(),
            float: float()
          }

    defstruct atom: :atom,
              bool: true,
              int: 1,
              str: "str",
              float: 3.14
  end
end
