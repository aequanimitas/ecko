defmodule Echo do
  @moduledoc """
  Documentation for Echo.
  """

  @doc """
  Tasks of this function
  - wraps process creation
  - sends a message to the spawned process
  - wait for a reply
  """
  def go do
    pid = spawn(__MODULE__, :loop, [])
    send(pid, {self(), :hello})
    receive do
      {^pid, msg} ->
        IO.inspect msg
    end
    send(pid, :stop)
  end

  @doc """
  Intentionally suspend in receive expression
  """
  def go_suspended do
    pid = spawn(__MODULE__, :loop, [])
    send(spawn(fn -> true end), {self(), :hello})
    receive do
      {^pid, msg} ->
        IO.inspect msg
    end
    send(pid, :stop)
  end

  @doc """
  Suspend but wait there's more
  """
  def go_with_timeout do
    pid = spawn(__MODULE__, :loop, [])
    send(spawn(fn -> true end), {self(), :hello})
    receive do
      {^pid, msg} ->
        IO.inspect msg
    after
      1_000 -> IO.inspect "no replies received"
    end
    send(pid, :stop)
  end

  @doc """
  My first registered process
  """
  def go_registered do
    Process.register(spawn(__MODULE__, :loop, []), :echo)
    send(:echo, {self(), :hello})
    receive do
      {_pid, msg} ->
        IO.inspect ":echo registered?: #{:echo in Process.registered()}"
        IO.inspect msg
    end
    send(:echo, :stop)
  end

  @doc """
  Using other :atoms
  """
  def using_spawn_for_registered_proc do
    Process.register(spawn(__MODULE__, :loop, []), :spawn)
    send(:spawn, {self(), :hello})
    receive do
      {pid, msg} ->
        IO.inspect ":spawn registered?: #{:spawn in Process.registered()}"
        IO.inspect msg

      :stop ->
        true
    end
  end

  def send_into_unknown do
    try do
      send(:hey, :hello)
    rescue
      ArgumentError ->
        IO.inspect "Invalid argument, proc with registered name should exist"
    end
  end

  @doc """
  Pulls messages from the process mailbox. 
  """
  def loop do
    receive do
      {from, msg} ->
        IO.inspect "Current proc: "
        IO.inspect self()
        :timer.sleep(1_000)
        send(from, {self(), msg})
        loop()
      :stop ->
        IO.inspect self()
        IO.inspect "stopping..."
        true
    end
  end

  @doc """
  Force memory leak by passing messages that cannot be matched by the clause

  Example

    iex> pid = spawn(Echo, :forced_leak, [])
    iex> send(pid, 1)
    iex> send(pid, 2)
    iex> send(pid, 3)
    iex> send(pid, 4)
    iex> Process.info(pid, :message_queue_len)
    {:message_queue_len, 4}
    iex> Process.info(pid, :messages)
    {:messages, [1,2,3,4]}

  On the last Process.info, we peeked at the mailbox of the spawned
  process. When peeking, messages are copied into the peeker's mailbox,
  in this case the repl process. When the 
  """
  def forced_leak do
    receive do
      :super_secret_pattern ->
        IO.inspect "Finally"
        forced_leak()
    end
  end
end
