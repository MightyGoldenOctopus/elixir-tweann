defmodule Cortex do

  defstruct id: nil,
            sensor_ids: [],
            actuator_ids: [],
            nids: []
  
  def gen(exoself_pid) do
    '''
    Starts the cortex process
    '''
    spawn_link fn -> loop(exoself_pid) end
  end

  def loop(exoself_pid) do
    '''
    Standby to receive the parent exoself order to initalize NN
    '''
    receive do
      {^exoself_pid, {id, spids, apids, npids}, tot_steps} ->
        # Send initialization order to all sensors processes
        Enum.map(spids, fn(spid) -> send(spid, {self(), :sync}) end)
        # Proceed to the feed-forward process
        loop(id, exoself_pid, spids, {apids, apids}, npids, tot_steps)
    end
  end

  def loop(id, exoself_pid, spids, {apids, apids_memory}, npids, 0) do
    ''' 
    End-case when all the feed-forward steps are finished, 
    back-up and terminates the NN
    '''
    neurons_id_and_weights = get_backup(npids, [])
    send(exoself_pidm {self(), :backup, neurons_ids_and_weights})
    
    Enum.map(spids, fn(spid)    -> send(spid, {self(), :terminate}) end)
    Enum.map(apids, fn(apid)    -> send(apid, {self(), :terminate}) end)
    Enum.map(npids, fn(npid)    -> send(npid, {self(), :terminate}) end)

    Enum.map(apids_memory, fn(mapid) -> send(mapid, {self(), :terminate}) end)
  end

  def loop(id, exoself_pid, spids, {[apid|next_apids], apids_memory}, npids, step) do
    '''
    Checking for the `sync` callbacks of the actuator processes.
    '''
    receive do
      {^apid, :sync} ->
        # Received callback of the current actuator (`apid`), checking callbacks of the next proccesses
        loop(id, exoself_pid, spids, {next_apids, apids_memory}, npids, step)
      :terminate ->
        Enum.map(spids, fn(spid) -> send(spid, {self(), :terminate}) end)
        Enum.map(apids_memory, fn(mapid) -> send(mapid, {self(), :terminate} end)
        Enum.map(npids, fn(npid) -> send(npid, {self(), :terminate}) end)
    end
  end

  def loop(id, exoself_pid, spids, {[], apids_memory}, npids, step) do
    '''
    When all actuators callbacks are checked, initialize sensors for
    a new feed-forward step, then we wait again for the callbacks of all
    actuators proccesses saved in `apids_memory`.
    '''
    Enum.map(spids, fn(spid) -> send(spid, {self(), :sync}) end)
    loop(id, exoself_pid, spids, {apids_memory, apids_memory}, npids, step-1)
  end

  def get_backup([npid|next_npids], acc) do
    '''
    Orders to all the neurons to send a backup of their ids and weights.
    And then recursively store it upon reception.
    '''
    send(npid, {self()}, :get_backup})
    receive do
      {^npid, nid, weight_tuples} ->
        get_backup(next_npids, [{nid, weight_tuples}]|acc])
    end
  end

  def get_backup([], acc) do
  '''
  End-case when all neurons have sent back their backup
  '''
  acc
  end

end
