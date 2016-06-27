require "xmlrpc/server"
require "socket"

s = XMLRPC::Server.new(ARGV[0])

class MyAlggago
  def sum_difference(a, b)
    { "sum" => a + b, "difference" => a - b }
  end

  def get_name
    "AI WHITE"
  end
end

s.add_handler("alggago", MyAlggago.new)
s.serve
