defmodule Exoself do

  alias Neuron
  alias Sensor
  alias Actuator
  alias Cortex

  def map(file_name) do
    {:ok, genotype} = :file.consult(file_name)
    # Mapping the genome can take some time
    task = Task.async(fn -> map(file_name, genotype) end)
    Task.await(task)
  end

  def map(file_name, genotype) do
    '''
    Generating a network from the genotype file
    and initializing the evolutionary procedure
    '''
    {v1, v2, v3} = {:os.system_time, :os.system_time, :os.system_time}
    :random.seed(v1, v2, v3)
    # Creating a record linking ids and pids
    ids_and_pids            = :ets.new(:id_and_pids, [:set, :private])

    cortex                  = Genotype.read(genotype, :cortex)
    sensor_ids              = cortex.sensor_ids
    actuator_ids            = cortex.actuator_ids
    nids                    = cortex.nids
    scape_pids              = spawn_scapes(ids_and_pids, cortex, [cortex.id])

    spawn_cerebral_units(ids_and_pids, Cortex, [cortex.id])
    spawn_cerebral_units(ids_and_pids, Sensor, sensor_ids)
    spawn_cerebral_units(ids_and_pids, Actuator, actuator_ids)
    spawn_cerebral_units(ids_and_pids, Neuron, nids)

    cerebral_units          = List.flatten([sensor_ids, actuator_ids, nids])

    link_cerebral_units(cerebral_units, ids_and_pids)
    {spids, npids, apids}   = link_cortex(cortex, ids_and_pids)

    cx_pid = :ets.lookup_element(ids_and_pids, cortex.id, 2)
    
    loop(file_name, genotype, ids_and_pids, cx_pid, spids, npids, apids, scape_pids, 0, 0, 0, 0, 1)
  end

  def loop(file_name, genotype, ids_and_pids, cx_pid, spids, npids, apids, scape_pids, highest_fitness, eval_acc, cycle_acc, time_acc, attempt) do
    '''
    For each iteration of NN, save it's genotype if it's fitness > highest fitness, if not, perturb it's weights
    unless it's weights have already been perturbed without increasing fitness for n times with n > max_attempts
    '''
    receive do
      {^cx_pid, :evaluation_completed, fitness, cycles, time} ->
        {new_highest_fitness, new_attempt} = case fitness > highest_fitness do
          true ->
            Enum.map(npids, fn(npid) -> send(npid, {self(), :weight_backup}) end)
            # Fitness increased, reset number of fitness attempts to 0
            {fitness, 0}
          false ->
            perturbed_npids = get(:perturbed)
            Enum.map(perturbed_npids, fn(npid) -> send(npid, {self(), :weight_restore}))
        end
        ## FIXME: Incomplete function
    end
  end

  def spawn_cerebral_units(ids_and_pids, cerebral_unit_type, [id|next_ids]) do
    '''
    Spawn the cerebral units processes
    '''
    pid = apply(cerebral_unit_type, :gen, [self()])
    :ets.insert(ids_and_pids, {id, pid})
    :ets.insert(ids_and_pids, {pid, id})
    spawn_cerebral_units(ids_and_pids, cerebral_unit_type, next_ids)
  end

  def spawn_cerebral_units(_ids_and_pids, _cerebral_unit_type, []), do: true

  def link_cerebral_units([%Sensor{} = sensor|records], ids_and_pids) do
    '''
    Link sensor cerebral unit
    '''
    sid         = sensor.id
    spid        = :ets.lookup_element(ids_and_pids, sid, 2)
    cx_pid      = :ets.lookup_element(ids_and_pids, sensor.cx_id, 2)
    s_name      = sensor.name
    fanout_ids  = sensor.fanout_ids
    fanout_pids = Enum.map(fanout_ids, fn(fanout_id) ->
                                       :ets.lookup_element(ids_and_pids, fanout_id, 2) end)
    # Send initialization order to spawned sensor
    send(spid, {self(), {sid, cx_pid, s_name, sensor.vl, fanout_pids}})
    # Proceed to the next cerebral unit to link
    link_cerebral_units(records, ids_and_pids)
  end

  def link_cerebral_units([%Actuator{} = actuator|records], ids_and_pids) do
    '''
    Link actuator cerebral unit
    '''
    aid         = actuator.id
    apid        = :ets.lookup_element(ids_and_pids, aid, 2)
    cx_pid      = :ets.lookup_element(ids_and_pids, actuator.cx_id, 2)
    a_name      = actuator.name
    fanin_ids   = actuator.fanin_ids
    fanin_pids  = Enum.map(fanin_ids, fn(fanin_id) ->
                                      :ets.lookup_element(ids_and_pids, fanin_id, 2) end)
    # Send initialization order to spawned actuator
    send(apid, {self(), {aid, cx_pid, a_name, fanin_pids}})
    # Proceed to the next cerebral unit to link
    link_cerebral_units(records, ids_and_pids)
  end

  def link_cerebral_units([%Neuron{} = neuron|records], ids_and_pids) do
    '''
    Link neuron cerebral unit
    '''
    nid         = neuron.id
    npid        = :ets.lookup_element(ids_and_pids, nid, 2)
    cx_pid      = :ets.lookup_element(ids_and_pids, neuron.cx_id, 2)
    af_name     = neuron.af
    input_idps  = neuron.input_idps
    output_ids  = neuron.output_ids
    # Encoding weights in tuples containing pid (`pidps`)
    input_pidps = convert_idps_to_pidps(ids_and_pids, input_idps, [])
    output_pids = Enum.map(output_ids, fn(output_id) ->
                                       :ets.lookup_element(ids_and_pids, output_id, 2) end)
    # Send initialization order to spawned neuron
    send(npid, {self(), {nid, cx_pid, af_name, input_pidps, output_pids}})
    # Proceed to the next cerebral unit to link
    link_cerebral_units(records, ids_and_pids)
  end

  def link_cerebral_units([], _ids_and_pids), do: :ok

  def convert_idps_to_pidps(_ids_and_pids, [{:bias, bias}], acc) do
    '''
    End-case when there is only the bias remaining
    '''
    Enum.reverse([bias|acc])
  end

  def convert_idps_to_pidps(ids_and_pids, [{id, weights}|next_fanin_idps], acc) do
    '''
    Look for the corresponding pid to make an pidps
    '''
    convert_idps_to_pidps(ids_and_pids, next_fanin_idps, [{:ets.lookup_element(ids_and_pids, id, 2), weights}|acc])
  end

  def link_cortex(cx, ids_and_pids) do
    cx_id     = cx.id
    cx_pid    = :ets.lookup_element(ids_and_pids, cx_id, 2)
    sids      = cx.sensor_ids
    aids      = cx.actuator_ids
    nids      = cx.nids
    spids     = Enum.map(sids, fn(sid) ->
                               :ets.lookup_element(ids_and_pids, sid, 2) end)
    apids     = Enum.map(aids, fn(aid) ->
                               :ets.lookup_element(ids_and_pids, aid, 2) end)
    npids     = Enum.map(nids, fn(nid) ->
                               :ets.lookup_element(ids_and_pids, nid, 2) end)
    # Send initialization order to spawned cortex
    send(cx_pid, {self(), {cx_id, spids, apids, npids}, 1000})
  end

  def update_genotype(ids_and_pids, genotype, [{n_id, pidps}|weightps]) do
    '''
    Saving the current neurons weights/connections into the genotype
    '''
    neuron_index        = Enum.find_index(genotype, fn(x) -> x.id == n_id end)
    neuron              = Enum.at(genotype, neuron_index)
    updated_input_idps  = convert_pidps_to_idps(ids_and_pids, pidps, [])
    updated_neuron      = %Neuron{neuron|input_idps: updated_input_idps}
    updated_genotype    = List.replace_at(genotype, neuron_index, updated_neuron)
    update_genotype(ids_and_pids, updated_genotype, weightps)
  end

  def update_genotype(_ids_and_pids, genotype, []), do: genotype

  def convert_pidps_to_idps(ids_and_pids, [{pid, weights}|next_input_idps], acc) do
    convert_pidps_to_idps(ids_and_pids, next_input_idps, [{:ets.lookup_element(ids_and_pids, pid, 2), weights}|acc])
  end

  def convert_pidps_to_idps(_ids_and_pids, [bias], acc), do: Enum.reverse([{:bias, bias}|acc])

end
