defmodule Trainer do

  alias Sensor
  alias Actuator
  alias Neuron
  alias Cortex

  def go(morphology, hidden_layer_densities) do
    '''
    Initializes the trainer process with default values
    '''
    go(morphology, hidden_layer_densities, 5, :infinity, :infinity)
  end

  def go(morphology, hidden_layer_densities, max_attempts, eval_limit, fitness_target) do
    '''
    Initialize the trainer process
    '''
    pid = spawn_link fn() ->
                     loop(morphology, hidden_layers_densities, fitness_target, {1, max_attemps}, {0, eval_limit}, {0, :best_genotype}, :experimental_genotype) end
    Process.register(pid, :trainer)
  end

  def loop(morphology, hl_densities, fitness_target, {attempt_acc, max_attempts}, {eval_acc, max_eval}, {best_fitness, best_g}, _exp_g, c_acc, t_acc) when attempt_acc >= max_attempts || eval_acc >= max_eval || best_fitness >= fitness_target do
    '''
    Show results when one NN has reach it's target or it's failed attemps/eval limit
    '''
    Genotype.print(best_g)
    :io.format("Morphology:~p Best Fitness:~p EvalAcc~p~n", [morphology, best_fitness, eval_acc])
  end

  def loop(morphology, hl_densities, fitness_target, {attempt_acc, max_attemps}, {eval_acc, max_eval}, {best_fitness, best_g}, exp_g, c_acc, t_acc) do
    '''
    Construct genotype and spawn the NN and then proceed to the training loop
    '''
    Constructor.construct_genotype(exp_g, morphology, hl_densities)
    agent_pid = Exoself.map(exp_g)
  
    receive do
      {agent_pid, fitness, evals, cycles, time} ->
        new_eval_acc  = eval_acc + evals
        new_c_acc     = c_acc + cycles
        new_t_acc     = t_acc + time
        case fitness > best_fitness do
          true ->
            :file.rename(exp_g, best_g)
            loop(morphology, hl_densities, fitness_target, {attempt_acc + 1, max_attemps}, {new_eval_acc, eval_limit}, {best_fitness, best_g}, exp_g, new_c_acc, new_t_acc)
          false ->
            loop(morphology, hl_densities, fitness_target, {attempt_acc + 1, max_atteps}, {new_eval_acc, eval_limit}, {best_fitness, best_g}, exp_g, new_c_acc, new_t_acc) 
        end
      :terminate ->
        :io.format("Trainer Terminated:~n")
        Genotype.print(best_g)
        :io.format("Morphology:~p Best Fitness:~p EvalAcc:~p~n", [morphology, best_fitness, eval_acc])
    end
  end

end
