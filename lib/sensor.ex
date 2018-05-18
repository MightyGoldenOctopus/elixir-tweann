defmodule Sensor do
  
  defstruct id: nil,
            cx_id: nil,
            name: nil,
            vl: 0,
            fanout_ids: []

  def gen(exoself_pid) do
    spawn_link fn -> loop(exoself_pid) end
  end

  def loop(exoself_pid) do
    '''
    Standby for initialization order from the exoself
    '''
    receive do
      {^exoself_pid, {id, cx_pid, sensor_name, vl, fanout_pids}} ->
        loop(id, cx_pid, sensor_name, vl, fanout_pids)
    end
  end

  def loop(id, cx_pid, sensor_name, vl, fanout_pids) do
    '''
    Standby for cortex order to collect data or to terminate
    '''
    receive do
      {^cx_pid, :sync} ->
        # Evaluating the given sensor function
        sensory_vector = apply(__MODULE__, sensor_name, [vl])
        # Forwarding result to connected neurons
        Enum.map(fanout_pids, fn(fanout_pid) -> 
                              send(fanout_pid), {self(), :forward, sensory_vector} end)
        loop(id, cx_pid, sensor_name, vl, fanout_pids)
      {^cx_pid, :terminate} ->
        :ok
    end
  end

  def rng(vl), do: rng(vl, [])

  def rng(0, acc), do: acc

  def rng(vl, acc), do: rng(vl-1, [:rand.uniform()|acc])

end
