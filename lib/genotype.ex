defmodule Genotype do

  def save_genotype(file_name, genotype) do
    '''
    Saving a genotype into an ETS table format
    '''
    table = :ets.new(file_name, [:public, :set, {:keypos, 2}])
    Enum.map(genotype, fn(element) -> :ets.insert(table, element) end)
    :ets.tab2file(table, file_name)
  end

  def save_to_file(genotype, file_name) do
    '''
    Save an ETS table to file
    '''
    :ets.tab2file(genotype, file_name)
  end

  def load_from_file(file_name) do
    {:ok, table} = :ets.file2tab(file_name)
    table
  end

  def read(table, key) do
    '''
    Read the record associated to the `key` argument in the specifiec `table` ETS table.
    '''
    [record] = :ets.lookup(table, key)
    record
  end

  def write(table, record) do
    '''
    Write a record on the specified ETS table
    '''
    :ets.insert(table, record)
  end

  def print(file_name) do
    '''
    Print the content of the selected genotype
    '''
    genotype  = load_from_file(file_name)
    cortex    = read(genotype, cortex)
    sids      = cortex.sensor_ids
    nids      = cortex.nids
    aids      = cortex.actuator_ids

    :io.format("~p~n", [cortex])
    [:io.format("~p~n", Enum.map(sids, fn(sid) -> read(genotype, sid) end))]
    [:io.format("~p~n", Enum.map(nids, fn(nid) -> read(genotype, nid) end))]
    [:io.format("~p~n", Enum.map(aids, fn(aid) -> read(genotype, aid) end))]
  end

end
