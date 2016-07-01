require "xmlrpc/server"
require "socket"

s = XMLRPC::Server.new(ARGV[0])
MAX_NUMBER = 16000

class MyAlggago
  def calculate(positions)

    #Codes here
    my_position = positions[0]
    your_position = positions[1]

    current_stone_number = 0
    index = 0
    min_length = MAX_NUMBER
    x_length = MAX_NUMBER
    y_length = MAX_NUMBER

    my_position.each do |my|
      your_position.each do |your|

        x_distance = (my[0] - your[0]).abs
        y_distance = (my[1] - your[1]).abs
        
        current_distance = Math.sqrt(x_distance * x_distance + y_distance * y_distance)

        if min_length > current_distance
          current_stone_number = index
          min_length = current_distance
          x_length = your[0] - my[0]
          y_length = your[1] - my[1]
        end
      end
      index = index + 1
    end

    #Return values
    message = positions.size
    stone_number = current_stone_number
    stone_x_strength = x_length * 5
    stone_y_strength = y_length * 5
    return [stone_number, stone_x_strength, stone_y_strength, message]

    #Codes end
  end

  def get_name
    "MY AI!!!"
  end
end

s.add_handler("alggago", MyAlggago.new)
s.serve
