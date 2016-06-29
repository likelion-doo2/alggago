require "xmlrpc/server"
require "socket"

s = XMLRPC::Server.new(ARGV[0])

class MyAlggago
  def calculate(positions)

    #Codes here

    #Return values
    message = positions.size
    stone_number = 0
    stone_x_strength = 300
    stone_y_strength = 400
    return [stone_number, stone_x_strength, stone_y_strength, message]
  end

  def get_name
    "AI BLACK"
  end
end

s.add_handler("alggago", MyAlggago.new)
s.serve
