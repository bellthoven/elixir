defmodule Binary do
  @moduledoc """
  Functions for working with binaries.
  """

  @doc %B"""
  Receives a char list and escapes all special chars (like \n)
  and interpolation markers. A last argument is given and wraps
  the whole char list given.

  ## Examples

      Binary.escape "foo", ?'
      #=> "'foo'"

  """
  def escape(other, char) do
    <<char>> <> do_escape(other, char)
  end

  @doc """
  Extracts a part from the binary according the given `start` and `length`.

  If a negative length is given, it takes the length counting back from
  the given start.

  If length is out of bounds (i.e. the binary is too short for the given
  length), it returns the available part.

  If start is out of bounds, it simply returns nil.

  ## Examples

      Binary.part("foobar", 1, 2)  #=> "oo"
      Binary.part("foobar", 3, -3) #=> "foo"
      Binary.part("foobar", 3, 6)  #=> "bar"
      Binary.part("foobar", 0, -3) #=> ""

  """
  def part(binary, start, length) when start >= 0 do
    size = size(binary)

    if start <= size do
      if length > 0 do
        if start + length > size do
          length = size - start
        end
      else
        if length + start < 0 do
          length = -start
        end
      end

      :binary.part(binary, start, length)
    end
  end

  @doc """
  Extracts a part from the binary according the given `range`.

  The range first and last must refer to positions in the binary.
  If first or last are negative, they are counted from the end of
  the binary.

  ## Examples

      Binary.part("foo", 1..2)      #=> "oo"
      Binary.part("foobar", 2..4)   #=> "oba"
      Binary.part("foobar", 0..0)   #=> "f"
      Binary.part("foobar", 0..-1)  #=> "foobar"
      Binary.part("foobar", 1..-2)  #=> "ooba"
      Binary.part("foobar", -3..-1) #=> "bar"

  """
  def part(binary, Range[first: first, last: last]) do
    if first < 0 do
      first = first + size(binary)
    end

    if last < 0 do
      last = last + size(binary)
    end

    length = last - first + 1
    part(binary, first, length)
  end

  @doc """
  Divides a binary into sub binaries based on a pattern,
  returning a list of these sub binaries. The pattern can
  be another binary, a list of binaries or a regular expression.

  The binary is split into two parts by default, unless
  `global` option is true. If a pattern is not specified,
  the binary is split on whitespace occurrences.

  It returns a list with the original binary if the pattern can't be matched.

  ## Examples

    Binary.split("a,b,c", ",")  #=> ["a", "b,c"]
    Binary.split("a,b,c", ",", global: true)  #=> ["a", "b,c"]
    Binary.split("foo bar")     #=> ["foo", "bar"]
    Binary.split("1,2 3,4", [" ", ","]) #=> ["1", "2 3,4"]
    Binary.split("1,2 3,4", [" ", ","], global: true) #=> ["1", "2", "3", "4"]
    Binary.split("a,b", ".")    #=> ["a,b"]

    Binary.split("a,b,c", %r{,})  #=> ["a", "b,c"]
    Binary.split("a,b,c", %r{,}, global: true) #=> ["a", "b", "c"]
    Binary.split("a,b", %r{\.})   #=> ["a,b"]

  """
  def split(binary, pattern // " ", options // [])

  def split(binary, pattern, options) when is_regex(pattern) do
    parts = if options[:global], do: :infinity, else: 2
    Regex.split(pattern, binary, parts: parts)
  end

  def split(binary, pattern, options) do
    options_list = []
    if options[:global] do
      options_list = [:global|options_list]
    end
    :binary.split(binary, pattern, options_list)
  end

  @doc """
  Checks if a binary is printable considering it is encoded
  as UTF-8. Returns true if so, false otherwise.

  ## Examples

      Binary.printable?("abc") #=> true

  """

  # Allow basic ascii chars
  def printable?(<<c, t|:binary>>) when c in ?\s..?~ do
    printable?(t)
  end

  # From 16#A0 to 16#BF
  def printable?(<<194, c, t|:binary>>) when c in 160..191 do
    printable?(t)
  end

  # From 16#C0 to 16#7FF
  def printable?(<<m, o1, t|:binary>>) when m in 195..223 and o1 in 128..191 do
    printable?(t)
  end

  # From 16#800 to 16#CFFF
  def printable?(<<m, o1, o2, t|:binary>>) when m in 224..236 and
      o1 >= 128 and o1 < 192 and o2 >= 128 and o2 < 192 do
    printable?(t)
  end

  # From 16#D000 to 16#D7FF
  def printable?(<<237, o1, o2, t|:binary>>) when
      o1 >= 128 and o1 < 160 and o2 >= 128 and o2 < 192 do
    printable?(t)
  end

  # Reject 16#FFFF and 16#FFFE
  def printable?(<<239, 191, o>>) when o == 190 or o == 191 do
    false
  end

  # From 16#E000 to 16#EFFF
  def printable?(<<m, o1, o2, t|:binary>>) when (m == 238 or m == 239) and
      o1 in 128..191 and o2 in 128..191 do
    printable?(t)
  end

  # From 16#F000 to 16#FFFD
  def printable?(<<239, o1, o2, t|:binary>>) when
      o1 in 128..191 and o2 in 128..191 do
    printable?(t)
  end

  # From 16#10000 to 16#3FFFF
  def printable?(<<240, o1, o2, o3, t|:binary>>) when
      o1 in 144..191 and o2 in 128..191 and o3 in 128..191 do
    printable?(t)
  end

  # Reject 16#110000 onwards
  def printable?(<<244, o1, _, _, _|:binary>>) when o1 >= 144 do
    false
  end

  # From 16#4000 to 16#10FFFF
  def printable?(<<m, o1, o2, o3, t|:binary>>) when m in 241..244 and
      o1 in 128..191 and o2 in 128..191 and o3 in 128..191 do
    printable?(t)
  end

  def printable?(<<?\n, t|:binary>>), do: printable?(t)
  def printable?(<<?\r, t|:binary>>), do: printable?(t)
  def printable?(<<?\t, t|:binary>>), do: printable?(t)
  def printable?(<<?\v, t|:binary>>), do: printable?(t)
  def printable?(<<?\b, t|:binary>>), do: printable?(t)
  def printable?(<<?\f, t|:binary>>), do: printable?(t)
  def printable?(<<?\e, t|:binary>>), do: printable?(t)

  def printable?(<<>>), do: true
  def printable?(_),    do: false

  @doc %B"""
  Unescape the given chars. The unescaping is driven by the same
  rules as single- and double-quoted strings. Check `unescape/2`
  for information on how to customize the escaping map.

  In this setup, Elixir will escape the following: `\b`, `\d`,
  `\e`, `\f`, `\n`, `\r`, `\s`, `\t` and `\v`. Octals are also
  escaped according to the latin1 set they represent.

  ## Examples

      Binary.unescape "example\\n"
      #=> "example\n"

  In the example above, we pass a string with `\n` escaped
  and we return a version with it unescaped.
  """
  def unescape(chars) do
    Erlang.elixir_interpolation.unescape_chars(chars)
  end

  @doc %B"""
  Unescape the given chars according to the map given.
  Check `unescape/1` if you want to use the same map as Elixir
  single- and double-quoted strings.

  ## Map

  The map must be a function. The function receives an integer
  representing the number of the characters it wants to unescape.
  Here is the default mapping function implemented by Elixir:

      def unescape_map(?b), do: ?\b
      def unescape_map(?d), do: ?\d
      def unescape_map(?e), do: ?\e
      def unescape_map(?f), do: ?\f
      def unescape_map(?n), do: ?\n
      def unescape_map(?r), do: ?\r
      def unescape_map(?s), do: ?\s
      def unescape_map(?t), do: ?\t
      def unescape_map(?v), do: ?\v
      def unescape_map(e), do: e

  If the `unescape_map` function returns false. The char is
  not escaped and `\` is kept in the char list.

  ## Octals

  Octals will by default be escaped unless the map function
  returns false for ?0.

  ## Examples

  Using the unescape_map defined above is easy:

      Binary.unescape "example\\n", unescape_map(&1)

  """
  def unescape(chars, map) do
    Erlang.elixir_interpolation.unescape_chars(chars, map)
  end

  @doc """
  Unescape the given tokens according to the default map.
  Check `unescape/1` and `unescape/2` for more information
  about unescaping. Only tokens that are char lists are
  unescaped, all others are ignored. This method is useful
  when implementing your own sigils. Check the implementation
  of `Kernel.__b__` for examples.
  """
  def unescape_tokens(tokens) do
    Erlang.elixir_interpolation.unescape_tokens(tokens)
  end

  @doc """
  Unescape the given tokens according to the given map.
  Check `unescape_tokens/1` and `unescaped/2` for more information.
  """
  def unescape_tokens(tokens, map) do
    Erlang.elixir_interpolation.unescape_tokens(tokens, map)
  end

  @doc """
  Returns a new binary based on `subject` by replacing the parts
  matching `pattern` for `replacement`. If `options` is specified
  with `[global: true]`, then it will replace all matches, otherwise
  it will replace just the first one.

  For the replaced part must be used in `replacement`, then the
  position or the positions where it is to be inserted must be specified by using
  the option `insert_replaced`.

  ## Examples

      > Binary.replace("a,b,c", ",", "-") #=> "a-b,c"
      > Binary.replace("a,b,c", ",", "-", global: true) #=> "a-b-c"
      > Binary.replace("a,b,c", "b", "[]", insert_replaced: 1) #=> "a,[b],c"
      > Binary.replace("a,b,c", ",", "[]", globa: true, insert_replaced: 2) #=> "a[],b[],c"
      > Binary.replace("a,b,c", ",", "[]", globa: true, insert_replaced: [1,1]) #=> "a[,,]b[,,]c"

  """
  def replace(subject, pattern, replacement, options // []) do
    real_options = translate_replace_options(options)
    Erlang.binary.replace(subject, pattern, replacement, real_options)
  end

  @doc """
  Returns a binary with `data` duplicated `n` times.

  ## Examples

      > Binary.duplicate("abc", 1) #=> "abc"
      > Binary.duplicate("abc", 2) #=> "abcabc"
  """
  def duplicate(data, n) when is_integer(n) and n > 0 do
    Erlang.binary.copy(data, n)
  end

  ## Helpers

  defp do_escape(<<char, t|:binary>>, char) do
    <<?\\, char, do_escape(t, char)|:binary>>
  end

  defp do_escape(<<h, t|:binary>>, char) when
    h == ?#  or h == ?\b or
    h == ?\d or h == ?\e or
    h == ?\f or h == ?\n or
    h == ?\r or h == ?\\ or
    h == ?\t or h == ?\v do
    <<?\\, escape_map(h), do_escape(t, char)|:binary>>
  end

  defp do_escape(<<h, t|:binary>>, char) do
    <<h, do_escape(t,char)|:binary>>
  end

  defp do_escape(<<>>, char) do
    <<char>>
  end

  defp escape_map(?#),  do: ?#
  defp escape_map(?\b), do: ?b
  defp escape_map(?\d), do: ?d
  defp escape_map(?\e), do: ?e
  defp escape_map(?\f), do: ?f
  defp escape_map(?\n), do: ?n
  defp escape_map(?\r), do: ?r
  defp escape_map(?\\), do: ?\\
  defp escape_map(?\t), do: ?t
  defp escape_map(?\v), do: ?v

  defp translate_replace_options([]) do
    []
  end

  defp translate_replace_options(options) do
    translated_options = []
    if options[:global] == true do
      translated_options = List.concat(translated_options, [:global])
    end
    if options[:insert_replaced] != nil do
      translated_options = List.concat(translated_options, [{:insert_replaced, options[:insert_replaced]}])
    end
    translated_options
  end

end
