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

  defmodule Echo do
    @moduledoc false

    @doc """
    If `start` is called more than once, you could end up with dangling processes
    """
    def start do
      pid = spawn(__MODULE__, :loop, [])
      IO.inspect pid
      Process.register(pid, :ecko)
    end

    def print(msg) do
      send(:ecko, {:print, msg})
    end

    def stop do
      send(:ecko, :stop)
      :ok
    end

    def loop do
      receive do
        {:print, msg} ->
          IO.inspect msg
          loop()
        :stop ->
          Process.exit(self(), :normal)
      end
    end
  end

  defmodule Ring do
    @moduledoc """
    On my machine, it should have atleast 3 processes to avoid
    race conditions. Maybe there's a better way to do this but can't find
    at the moment

    I have 2 ways on my mind rigt now on how to solve this:
    1. "Bubbling" - let the message propagate all the way up to the initial
       process. The trade off is you have to pass a message to all spawned
       processes and check if it has a parent.

    2. passing the initial process to all spawned processes. Each sub-process
       gets a copy of the initial proc's PID. Trade off here is each process
       gets a copy of a thing that they might not need unless the process
       is the last one that was spawned
    """

    def start(m, n, message) do
      pid = spawn(__MODULE__, :loop, [nil, nil])
      IO.inspect "Initial pid: "
      IO.inspect pid
      send(pid, {:start_kid, pid, n - 1, message})
      send(pid, {:new_msg, m - 1, message})
      pid
    end

    def loop(ppid, kpid) do
      receive do
        {:start_kid, parent_pid, 1, message} ->
          pid = spawn(__MODULE__, :loop, [parent_pid, nil])
          IO.puts "-------------------------"
          IO.inspect "Starting last process!"
          IO.inspect pid
          IO.puts "-------------------------"
          loop(ppid, nil)
        {:start_kid, parent_pid, n, message} ->
          pid = spawn(__MODULE__, :loop, [parent_pid, nil])
          send(pid, {:start_kid, pid, n - 1, message})
          IO.puts "-------------------------"
          IO.inspect "Initializing kid process..."
          IO.inspect pid
          IO.puts "-------------------------"
          loop(ppid, pid)
        {:new_msg, 0, message} ->
          IO.puts "-------------------------"
          IO.inspect message
          IO.inspect "DONE!"
          IO.puts "-------------------------"
          loop(ppid, kpid)
        {:new_msg, m, message} ->
          case kpid == nil do
            true ->
              IO.puts "-------------------------"
              IO.inspect "I have no spawned process: "
              IO.inspect self()
              IO.puts "-------------------------"
              send(ppid, {:find_parent, :new_msg, m, message})
              loop(ppid, kpid)
            false ->
              IO.puts "-------------------------"
              IO.inspect "Receiver: "
              IO.inspect kpid
              IO.inspect "received message: #{message}"
              IO.inspect "message count: #{m}"
              IO.puts "-------------------------"
              send(kpid, {:new_msg, m - 1, message})
              loop(ppid, kpid)
          end
        {:find_parent, :new_msg, m, message} ->
          case ppid == nil do
            true ->
              IO.puts "-------------------------"
              IO.inspect "Initial received message: #{message}"
              IO.inspect self()
              IO.puts "-------------------------"
              send(kpid, {:new_msg, m - 1, message})
              loop(ppid, kpid)
            false ->
              send(ppid, {:find_parent, :new_msg, m, message})
              loop(ppid, kpid)
          end
        :stop ->
          Process.exit(self(), :stop)
      end
    end
  end
end
