defmodule Neuron do
  
  defstruct id: nil,
            cx_id: nil,
            af: nil,
            input_idps: [],
            output_ids: []

  def gen(exoself_pid) do
    spawn_link fn -> loop(exoself_pid) end
  end

  def loop(exoself_pid) do
    '''
    Standby for initialization order from exoself
    '''
    receive do
      {^exoself_pid, {id, cx_pid, af, input_pidps, output_pids}} ->
        loop(id, cx_pid, af, {input_pidps, input_pidps}, output_pids, 0)
    end
  end

  def loop(id, cx_pid, af, {[{input_pid, weights}|next_input_pidps], input_pidps_memory} = input_pidps, output_pids, acc) do
    '''
    Standby for input signal from preceding neurons/sensors, or for
    backup order from cortex or finally for termination order.
    '''
    receive do
      {^input_pid, :forward, input} ->
        # Accumulating a single input into the input vector
        result = dot(input, weights, 0)
        loop(id, cx_pid, af, {next_input_pidps, input_pidps_memory}, output_pids, result+acc)
      {^cx_pid, :get_backup} ->
        send(cx_pid, {self(), id, input_pidps_memory})
        # Go back standby for inputs
        loop(id, cx_pid, af, input_pidps, output_pids, acc)
      {^cx_pid, :terminate} ->
        :ok
    end
  end

  def loop(id, cx_pid, af, {[bias], input_pidps_memory}, output_pids, acc) do
    '''
    In case if there is a bias at the end of the input vector, take it 
    in account and apply the given activation function `af`.
    '''
    output = apply(__MODULE__, af, [acc+bias])
    Enum.map(output_pids, fn(output_pid) ->
                          send(output_pid, {self(), :forward, [output]}) end)
    # Clear the accumulator and go back standby for input/termination
    loop(id, cx_pid, af, {input_pidps_memory, input_pidps_memory}, output_pids, 0)
  end

  def loop(id, cx_pid, af, {[], input_pidps_memory}, output_pids, acc) do
    '''
    If there's no bias at the end of the input vector, simply
    apply the given activation function `af` to it.
    '''
    output = apply(__MODULE__, af, [acc])
    Enum.map(output_pids, fn(output_pid) -> send(output_pid, {self(), :forward, [output]}) end)
    loop(id, cx_pid, af, {input_pidps_memory, input_pidps_memory}, output_pids, 0)
  end

  def tanh(x), do: :math.tanh(x)

  def dot([i|next_inputs], [w|next_weights], acc) do
    dot(next_inputs, next_weights, i*w+acc)
  end

  def dot([], [bias], acc), do: acc+bias

  def dot([], [], acc), do: acc

end
