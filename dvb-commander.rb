#! /usr/bin/ruby

require 'socket'
SERVER_IP_ADDRESS = "131.114.53.243"
PORT = "8100"

ALLOWED_COMMANDS = %w[help h list l search s mux m]
HELP_COMMANDS = %w[help h]

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

def retrieve(file_in)   #generate a hash with key = mux frequency => [program]
    f = File.open("channels.conf")
    channels = Hash.new
    f.each do |line|
      s = line.split(/:/)
      program = Programs.new(*s)      
      (channels[program.frequency] ||= []) << program
    end
    return channels
end

######################################################################
################ Section of help methods #############################
######################################################################

def help(*s)
  if s.length == 0 
    message = "List of commands: help, list, search, mux"
  else
    if ALLOWED_COMMANDS.include? s[0] then
      message = send "help_#{s[0]}" 
    else
      message "Sorry: no entry..."
    end
  end
  return message
end

alias h help


def help_list()
    message = "Print list of avaliable channels"
end

alias help_l help_list

def help_search()
    message = "Search the specified program in the list of avaliable channels"
end

alias help_s help_search


def help_mux()
    message = "Print all available transponders"
end

alias help_m help_mux

def helpers(line)
  command = line[0]
  if line.length-1 > 0 then
    message = send command.to_sym, "#{line[1..line.length-1]}"
  else
    message = send command.to_sym
  end
end

######################################################################
################ Section of commanders methods #######################
######################################################################



def list(channels,*frequency)
  if frequency.length == 0 
    response = channels.to_s
  else
    response = ""
    frequency.each {|f|; message += channels[f]}
  end
end

alias l list 

def mux(channels,*extra)  #Extra paramteres are simply ignored
  return channels.keys
end

alias m mux



def search(channels,*pattern)
  response = []
  if pattern.length >= 1 then
    (channels.values).each do |array_of_programs|
      array_of_programs.each do |program|
        if program.name.include?(pattern[0]) then 
           response << program
        end 
      end
    end
  end
  return response
end

alias s search

def commanders(channels,line)
  command = line[0]
  if line.length > 1 then
    response = send command.to_sym, channels, *line[1..line.length-1]
  else
    response = send command.to_sym, channels
  end
end


# Begin main program

channels = retrieve("channels.conf")

server = TCPServer.open(PORT)
STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil

# client = server.accept
# client.puts "Connected to DVB Commander at #{SERVER_IP_ADDRESS}:#{PORT}"
# client.flush
# client.close

begin 

client = server.accept
puts "Connected to DVB Commander from #{client}"
local, peer = client.addr, client.peeraddr 

loop do
  
  request = Marshal::load(client)
  STDOUT.print "Successfully received command from #{peer[2]}:#{peer[1]}" 
  STDOUT.puts " using local port #{local[1]}"
   
  line = request.split
  command=line[0]
  case
      #when !(Object.respond_to? command, true)  # true is for private methods of Object Class RISKY - use next condition instead!!!!
      when !(ALLOWED_COMMANDS.include? command) 
        Marshal::dump("Command not available",client)
      when (HELP_COMMANDS.include? command)
        message = helpers(line)
        Marshal::dump(message,client)
      else
        response = commanders(channels,line)
        Marshal::dump(response,client)

  end
end
#end

rescue
	STDERR.puts "Connection to client closed"
	STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil
	retry
end












