#! /usr/bin/ruby

require 'socket'

PORT = 8100

class Programs
  attr_accessor :name, :frequency, :inversion, :bandwidth, :fec, :fec_auto, :modulation, :t_mode, :guard_interval, :hierarchy, :apid, :vpid, :tpid
  
  def initialize(name, frequency, inversion, bandwidth, fec, fec_auto, modulation, t_mode,guard_interval, hierarchy, vpid, apid, sid)
    @name = name
    @frequency = frequency
    @inversion = inversion
    @bandwidth = bandwidth
    @fec = fec
    @fec_auto = fec_auto
    @modulation = modulation
    @t_mode = t_mode
    @guard_interval = guard_interval 
    @hierarchy = hierarchy
    @vpid = vpid                          # video pid
    @apid = apid                          # audio pid
    @sid = sid                            # service ID
  end
  
  def to_s
    "Name: #{@name}\nMUX: #{@frequency}\nInversion: #{@inversion}  Bandwidth: #{@bandwidth}  FEC: #{@fec}  FEC AUTO: #{@fec_auto}\nModulation: #{@modulation}  Transmission mode: #{@t_mode}  Guard Interval: #{@guard_interval}  Hierarchy: #{@hierarchy}\nVideo PID: #{@vpid}  Audio PID #{@apid}  Service ID: #{@sid}\n"
  end
end






host = ARGV[0]

# Begin main program

CLI_prompt = "DVB-remote > "

# server = TCPSocket.open(host, PORT)  # open connection for each line.... like http 1.0
# response = server.gets
# STDOUT.puts response
# server.close

STDOUT.print CLI_prompt
line = STDIN.gets

server = TCPSocket.open(host, PORT)  # open connection for each line.... like http 1.0

while (line.downcase.split)[0] != "quit" do
  
  Marshal::dump(line,server)
  
  response=Marshal::load(server)
  
  STDOUT.puts response
  
  STDOUT.print CLI_prompt
  line = STDIN.gets
end






