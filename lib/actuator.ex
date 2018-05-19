defmodule Actuator do

  defstruct id: nil,
            cx_id: nil,
            name: nil,
            vl: 0,
            fanin_ids: []

  def gen(exoself_pid) do
    spawn_link fn -> loop(exoself_pid) end
  end

  def loop(exoself_pid) do
    '''
    Standby for initialization order from the exoself
    '''
    receive do
      {^exoself_pid, {id, cx_pid, actuator_name, fanin_pids}} ->
        loop(id, cx_pid, actuator_name, {fanin_pids, fanin_pids}, [])
    end
  end

  def loop(id, cx_pid, actuator_name, {[fanin_pid|next_fanin_pids], fanin_pids_memory}, acc) do
    '''
    Standby for signal from preceding neurons or for termination 
    signal from the cortex.
    '''
    receive do
      {^fanin_pid, :forward, input} ->
        loop(id, cx_pid, actuator_name, {next_fanin_pids, fanin_pids_memory}, [input|acc])
      {^cx_pid, :terminate} ->
        :ok
    end
  end

  def loop(id, cx_pid, actuator_name, {[], fanin_pids_memory}, acc) do
    '''
    When all neurons have sent their signal, feed the accumulator
    in the given actuator function then send callback to cortex.
    Finally clear the accumulator and resume stanby for new signal.
    '''
    apply(__MODULE__, actuator_name, Enum.reverse(acc))
    send(cx_pid, {self(), :sync})
    loop(id, cx_pid, actuator_name, {fanin_pids_memory, fanin_pids_memory}, [])
  end

  def pts(result), do: :ok

end
