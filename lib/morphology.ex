defmodule Morphology do

  def xor_mimic(sensors) do
    '''
    Generate a list of sensors to interact with the XOR scape
    '''
    Enum.map(sensors, fn(sensor) -> %Sensor{id: {sensor, generate_id()}, name: :xor_get_input, scape: {:private, :xor_sim}} end)
  end

  def xor_mimic(actuators) do
    '''
    Generate a list of actuators to interact with the XOR scape
    '''
    Enum.map(actuators, fn(actuator) -> %Actuator{id: {actuator, generate_id()}, name: :xor_send_output, scape: {:private, :xor_sim}})
  end

  defp generate_id() {
    UUID.uuid1();
  }

end
