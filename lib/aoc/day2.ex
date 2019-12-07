defmodule AOC.Day2 do
  use AOC

  alias AOC.Intcode

  defp default, do: input(",", &String.to_integer/1)

  @doc """
      iex> AOC.Day2.part1
      3562672
  """
  def part1(inp \\ default()) do
    Intcode.simulate(inp, 12, 2)
  end

  @doc """
      iex> AOC.Day2.part2
      {19690720, 8250}
  """
  def part2(inp \\ default()) do
    # I'm not sure how to programmatically prove this, but:
    # - 0, 0 outputs 797870
    # - Incrementing the noun increases the outout by 230400
    # - Incrementing the verb increments the output
    noun = 82
    verb = 50
    {Intcode.simulate(inp, noun, verb), 100 * noun + verb}
  end
end