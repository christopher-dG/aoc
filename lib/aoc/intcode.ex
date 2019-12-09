defmodule AOC.Intcode do
  @moduledoc "Intcode simulator."

  use GenServer

  @add 1
  @mul 2
  @input 3
  @output 4
  @if 5
  @unless 6
  @lt 7
  @eq 8
  @rb 9
  @stop 99

  @position 0
  @immediate 1
  @relative 2

  @doc "Creates a new Intcode computer."
  def new(tape) do
    {:ok, pid} = start_link(tape)
    pid
  end

  @doc "Runs the computer's tape."
  def run(pid) do
    GenServer.cast(pid, :run)
    pid
  end

  @doc "Subscribes someone to the computer's events."
  def subscribe(pid, subscribers) do
    GenServer.cast(pid, {:subscribe, subscribers})
    pid
  end

  @doc "Sends input to the computer."
  def input(pid, val) do
    GenServer.cast(pid, {:input, val})
    pid
  end

  @doc "Gets the last output, assuming you've subscribed to exactly one computer."
  def last_output(timeout \\ :infinity, default \\ nil) do
    receive do
      :done -> default
      {:output, out} -> last_output(timeout, out)
    after
      timeout -> :timeout
    end
  end

  @doc "Get the tape as a list"
  def tape(pid), do: GenServer.call(pid, :tape)

  def start_link(tape), do: GenServer.start_link(__MODULE__, tape)

  def init(tape) do
    tape =
      tape
      |> Enum.with_index()
      |> Enum.map(fn {x, idx} -> {idx, x} end)
      |> Map.new()

    ic = %{
      tape: tape,
      subscribers: MapSet.new(),
      ip: 0,
      rb: 0,
      inputs: [],
      state: :stopped
    }

    {:ok, ic}
  end

  def handle_call(:tape, _from, %{tape: tape} = ic) do
    tape =
      tape
      |> Map.to_list()
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {_k, v} -> v end)

    {:reply, tape, ic}
  end

  def handle_cast(:run, ic), do: {:noreply, ic, {:continue, :run}}

  def handle_cast({:subscribe, new_subs}, %{subscribers: current_subs} = ic) do
    subs =
      if is_list(new_subs) do
        MapSet.union(current_subs, MapSet.new(new_subs))
      else
        MapSet.put(current_subs, new_subs)
      end

    {:noreply, %{ic | subscribers: subs}}
  end

  def handle_cast({:input, val}, %{inputs: inputs, state: state} = ic) do
    reply = {:noreply, %{ic | state: :waking, inputs: inputs ++ [val]}}
    if state === :sleeping, do: Tuple.insert_at(reply, 2, {:continue, :run}), else: reply
  end

  def handle_info({:output, val}, ic), do: handle_cast({:input, val}, ic)

  def handle_info(:done, ic), do: {:noreply, ic}

  def handle_continue(:run, ic), do: simulate(ic)

  def handle_continue(:stop, %{subscribers: subscribers} = ic) do
    Enum.each(subscribers, &send(&1, :done))
    {:noreply, ic}
  end

  defp simulate(%{tape: tape, subscribers: subscribers, ip: ip, rb: rb, inputs: inputs} = ic) do
    ic = %{ic | state: :running}

    instruction = tape[ip]
    opcode = rem(instruction, 100)

    modes =
      (instruction / 100)
      |> floor()
      |> Integer.digits()
      |> pad(3)

    case {modes, opcode} do
      {[0, 0, 0], @stop} ->
        {:noreply, %{ic | state: :stopped}, {:continue, :stop}}

      {[dest_mode, b_mode, a_mode], op} when op in [@add, @mul] ->
        a = load(tape, a_mode, rb, ip + 1)
        b = load(tape, b_mode, rb, ip + 2)
        dest = destination(tape, dest_mode, rb, ip + 3)

        f =
          case op do
            @add -> &+/2
            @mul -> &*/2
          end

        val = f.(a, b)
        tape = store(tape, dest, val)
        {:noreply, %{ic | tape: tape, ip: ip + 4}, {:continue, :run}}

      {[0, 0, mode], @input} ->
        mode = if mode == @position, do: @immediate, else: mode

        case inputs do
          [] ->
            {:noreply, %{ic | state: :sleeping}, :hibernate}

          [val | rest] ->
            dest = destination(tape, mode, rb, ip + 1)
            tape = store(tape, dest, val)
            {:noreply, %{ic | tape: tape, ip: ip + 2, inputs: rest}, {:continue, :run}}
        end

      {[0, 0, mode], @output} ->
        out = load(tape, mode, rb, ip + 1)
        Enum.each(subscribers, &send(&1, {:output, out}))
        {:noreply, %{ic | ip: ip + 2}, {:continue, :run}}

      {[0, branch_mode, val_mode], op} when op in [@if, @unless] ->
        val = load(tape, val_mode, rb, ip + 1)

        ip =
          if (op == @if and val != 0) or (op == @unless and val == 0) do
            load(tape, branch_mode, rb, ip + 2)
          else
            ip + 3
          end

        {:noreply, %{ic | ip: ip}, {:continue, :run}}

      {[dest_mode, b_mode, a_mode], op} when op in [@lt, @eq] ->
        a = load(tape, a_mode, rb, ip + 1)
        b = load(tape, b_mode, rb, ip + 2)
        dest = destination(tape, dest_mode, rb, ip + 3)
        val = if (op == @lt and a < b) or (op == @eq and a == b), do: 1, else: 0
        tape = store(tape, dest, val)
        {:noreply, %{ic | tape: tape, ip: ip + 4}, {:continue, :run}}

      {[0, 0, mode], @rb} ->
        offset = load(tape, mode, rb, ip + 1)
        {:noreply, %{ic | ip: ip + 2, rb: rb + offset}, {:continue, :run}}
    end
  end

  defp destination(tape, @relative, rb, idx), do: Map.get(tape, idx, 0) + rb
  defp destination(tape, _mode, _rb, idx), do: Map.get(tape, idx, 0)

  defp load(tape, @position, rb, idx), do: load(tape, @immediate, rb, Map.get(tape, idx, 0))
  defp load(tape, @immediate, _rb, idx), do: Map.get(tape, idx, 0)
  defp load(tape, @relative, rb, idx), do: load(tape, @immediate, rb, Map.get(tape, idx, 0) + rb)

  defp store(tape, idx, val), do: Map.put(tape, idx, val)

  defp pad(xs, n) when length(xs) == n, do: xs
  defp pad(xs, n) when length(xs) < n, do: pad([0 | xs], n)
end
