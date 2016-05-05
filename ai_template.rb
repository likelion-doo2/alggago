require "xmlrpc/server"
require "socket"

def is_port_open?(port)
  begin
    s = TCPServer.new("127.0.0.1", port)
  rescue Errno::ECONNREFUSED
    return false
  end
  s.close
  return true
end

xml_port = 0
(8000..8080).to_a.each do |p|
  if is_port_open?(p)
    xml_port = p
    break
  end
end

s = XMLRPC::Server.new(xml_port)

class MyHandler
  def sumAndDifference(a, b)
    { "sum" => a + b, "difference" => a - b }
  end
end

s.add_handler("sample", MyHandler.new)
s.serve
