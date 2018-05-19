defmodule Constructor do
  alias Neuron
  alias Sensor
  alias Actuator
  alias Cortex

  def construct_genotype(sensor_name, actuator_name, hidden_layer_densities) do
    construct_genotype(:unnamed_genotype, sensor_name, actuator_name, hidden_layer_densities)
  end

  def construct_genotype(file_name, sensor_name, actuator_name, hidden_layer_densities) do
    s               = create_sensor(sensor_name)
    a               = create_actuator(actuator_name)
    # length of actuator's output vector
    output_vl       = a.vl;
    layer_densities = List.flatten([hidden_layer_densities, output_vl])
    cx_id = {:cortex, generate_id()}

    neurons         = create_neuro_layers(cx_id, s, a, layer_densities)
    [input_layer|_] = neurons
    [output_layer|_]  = Enum.reverse(neurons)

    # ids of first layer's neurons
    fl_nids         = Enum.map(input_layer, fn(neuron) -> neuron.id end)
    # ids of last layer neurons
    ll_nids         = Enum.map(output_layer, fn(neuron) -> neuron.id end)
    #ids of all neurons
    nids            = Enum.map(List.flatten(neurons),
                      fn(neuron) -> neuron.id end)

    sensor          = %Sensor{s|cx_id: cx_id, fanout_ids: fl_nids}
    actuator        = %Actuator{a|cx_id: cx_id, fanin_ids: ll_nids}
    cortex          = create_cortex(cx_id, [s.id], [a.id], nids)

    genotype        = List.flatten([cortex, sensor, actuator|neurons])

    {:ok, file}     = :file.open(file_name, :write)
    :lists.foreach(fn(x) -> :io.format(file, "~p.~n", [x]) end, genotype)
    :file.close(file)
  end

  def create_sensor(sensor_name) do
    case sensor_name do
      :rng ->
        %Sensor{id: {:sensor, generate_id()}, name: :rng, vl: 2}
      _->
        exit("Sensor '#{sensor_name}' not supported")
    end
  end

  def create_actuator(actuator_name) do
    case actuator_name do
      :pts ->
        %Actuator{id: {:actuator, generate_id()}, name: :pts, vl: 1}
      _ ->
        exit("Actuator '#{actuator_name}' not supported")
    end
  end

  def create_neuro_layers(cx_id, sensor, actuator, layer_densities) do
    '''
    Initialize first layer inputs and metrics
    '''
    input_idps              = [{sensor.id, sensor.vl}]
    tot_layers              = length(layer_densities)
    [fl_neurons|next_lds]   = layer_densities
    nids                    = Enum.map(generate_ids(fl_neurons, []),
                              fn(id) -> {:neuron, {1, id}} end)
    create_neuro_layers(cx_id, actuator.id, 1, tot_layers, input_idps, nids, next_lds, [])
  end

  def create_neuro_layers(cx_id, actuator_id, layer_index, tot_layer, input_idps, nids, [next_layer_density|next_lds], acc) do
    '''
    Called recursively to build hidden layers connections
    '''
    output_nids     = Enum.map(generate_ids(next_layer_density, []),
                      fn(id) -> {:neuron, {1, id}} end)
    # Call the function that build layer's neurons
    layer_neurons   = create_neuro_layers(cx_id, input_idps, nids, output_nids, [])
    next_input_idps = Enum.map(nids, fn(nid) -> {nid, 1} end)
    # Proceed to next layer
    create_neuro_layers(cx_id, actuator_id, layer_index+1, tot_layer, next_input_idps, output_nids, next_lds, [layer_neurons|acc])
  end

  def create_neuro_layers(cx_id, actuator_id, _layer_index, _tot_layers, input_idps, nids, [], acc) do
    '''
    Initialize the neurons output ids and start the recursion
    '''
    output_ids      = [actuator_id]
    layer_neurons   = create_neuro_layers(cx_id, input_idps, nids, output_ids, [])
    Enum.reverse([layer_neurons|acc])
  end

  def create_neuro_layers(cx_id, input_idps, [nid|next_nids], output_ids, acc) do
    '''
    Recursively builds neurons
    '''
    neuron = create_neuron(input_idps, nid, cx_id, output_ids)
    create_neuro_layers(cx_id, input_idps, next_nids, output_ids, [neuron|acc])
  end

  def create_neuro_layers(_cx_id, _input_idps, [], _output_ids, acc) do
    '''
    End-case, returns the list of all layer's neurons
    '''
    acc
  end

  def create_neuron(input_idps, id, cx_id, output_ids) do
    '''
    Create a single neuron
    '''
    proper_input_idps = create_neural_input(input_idps, [])
    %Neuron{id: id,
            cx_id: cx_id,
            af: :tanh,
            input_idps: proper_input_idps,
            output_ids: output_ids}
  end

  def create_neural_input([{input_id, input_vl}|next_idps], acc) do
    '''
    Recursively create neuron's input connections and weights
    '''
    weights = create_neural_weights(input_vl, [])
    create_neural_input(next_idps, [{input_id, weights}|acc])
  end

  def create_neural_input([], acc) do
  '''
  End-case, adds the bias weight at the end of inputs list and returns it
  '''
  Enum.reverse([{:bias, :rand.uniform()-0.5}|acc])
  end

  def create_neural_weights(0, acc) do
    '''
    End-case, returns a weights vector
    '''
    acc
  end

  def create_neural_weights(index, acc) do
    '''
    Recursively create a weights vector of length `input_vl`
    '''
    w = :rand.uniform()-0.5
    create_neural_weights(index-1, [w|acc])
  end

  def generate_ids(0, acc) do
    '''
    End-case, returns an ids vector
    '''
    acc
  end

  def generate_ids(index, acc) do
    # Recursively create a vector of ids
    id = generate_id()
    generate_ids(index-1, [id|acc])
  end

  def generate_id() do
    '''
    Generates an unique identifier
    '''
    UUID.uuid1();
  end

  def create_cortex(cx_id, s_ids, a_ids, nids) do
    %Cortex{id: cx_id, sensor_ids: s_ids, actuator_ids: a_ids, nids: nids}
  end

end
