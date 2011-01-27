#! /usr/bin/ruby

require 'socket'

PORT = 8100

class Message
  attr_accessor :type, :content
  
  def initialize(type=Code::EOK)
          @type, @content = type, []
  end
  
  def fill(text)
          (@content ||= []) << text
  end
  
  def to_s
          "Message Type: #{@type}\n" + @content.join("\n")
  end
end




host = ARGV[0]

# Begin main program

server = TCPSocket.open(host, PORT)  # open connection for each line.... like http 1.0

server.puts "RubyTerminal"
response=Marshal::load(server)
STDOUT.puts response


CLI_prompt = "DVB-remote > "


# server = TCPSocket.open(host, PORT)  # open connection for each line.... like http 1.0
# response = server.gets
# STDOUT.puts response
# server.close

STDOUT.print CLI_prompt
line = STDIN.gets



while (line.downcase.split)[0] != "quit" do
  
  Marshal::dump(line,server)
  
  response=Marshal::load(server)
  
  STDOUT.puts response
  
  STDOUT.print CLI_prompt
  line = STDIN.gets
end






