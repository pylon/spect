# Spect

Type specification extensions for Elixir.

## Status
[![Hex](http://img.shields.io/hexpm/v/spect.svg?style=flat)](https://hex.pm/packages/spect)
[![Test](http://circleci-badges-max.herokuapp.com/img/pylon/spect?token=:circle-ci-token)](https://circleci.com/gh/pylon/spect)
[![Coverage](https://coveralls.io/repos/github/pylon/spect/badge.svg)](https://coveralls.io/github/pylon/spect)

The API reference is available [here](https://hexdocs.pm/spect/).

## Installation

```elixir
def deps do
  [
    {:spect, "~> 0.1.0"}
  ]
end
```

## Features

### Structure Decoding
Decoding data serialized with protocols that don't support all of
Erlang's/Elixir's types is a common problem. For example, JSON has no concept
of atoms/keywords for keys in maps. This means that serializing Elixir
`structs` to JSON is a lossy conversion.

Spect attempts to solve this problem by implementing a decoder `to_spec`
that can map from a primitive data structure representation onto a
typespec-defined representation. The most common application of this is to
convert a JSON tree into a nested Elixir structure. For example, consider
the following typespecs/structs:

```elixir
defmodule Smith do
  defmodule Parent do
    @type t :: %__MODULE__{
      name: String.t(),
      children: %{String.t() => Smith.Child.t()}
    }
    defstruct [name: nil, children: %{}]
  end

  defmodule Child do
    @type t :: %__MODULE__{
      name: String.t()
    }
    defstruct [name: nil]
  end
end
```

In this model, a `Parent` struct contains a map of strings to `Child`
structs. In each of the typed structs, the map keys should be `atoms`, and
in the untyped map, the keys should remain strings. Consider the following
JSON instance of the above structure:

```javascript
{
  "name": "Will",
  "children": {
    "firstborn": {
      "name": "Jayden"
    },
    "second": {
      "name": "Willow"
    }
  }
}
```

The following code would parse and decode this document into the correct
`Parent` structure, using the [Poison](https://github.com/devinus/poison)
parser:

```elixir
"smiths.json"
|> File.read!()
|> Poison.Parser.parse!()
|> Spect.to_spec!(Smith.Parent)
```

In the call to `to_spec!`, the `struct` module is passed. An optional
argument can be passed with the name of the `@type` definition, which defaults
to `:t`, the conventional spec name for structs. This expression should
evaluate to the following:

```elixir
>>> %Smiths.Parent{
  name: "Will",
  children: %{
    "firstborn" => %Smiths.Child{name: "Jayden"},
    "second" => %Smiths.Child{name: "Willow"}
  }
}
```

Note that the struct keys have been converted to atoms recursively, while the
"data" keys in the `children` map remain strings.

The Poison parser provides a simple mechanism for automatic nested structure
[decoding](https://github.com/devinus/poison#usage). However, it cannot be
used here without a priori knowledge of the keys in the `children` map
above. This can only be done using the typespec of the struct, which is what
Spect tries to do.

## License

Copyright 2018 Pylon, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
