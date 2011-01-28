#! /usr/bin/ruby -w

require 'rubygems'
require 'socket'
require 'nokogiri'
SERVER_IP_ADDRESS = "127.0.0.1"
PORT = "8100"
RUBY_TERMINAL = false
XML_PROGRAMS_FILE = "programs.xml"

ALLOWED_COMMANDS = %w[help h list l search s mux m live]
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
    @group = (vpid == 0)? "Radio" : "TV"
    @ip_address = []
  end
  
  def to_s
    "Name: #{@name}\nMUX: #{@frequency}\nInversion: #{@inversion}  Bandwidth: #{@bandwidth}  FEC: #{@fec}  FEC AUTO: #{@fec_auto}\nModulation: #{@modulation}  Transmission mode: #{@t_mode}  Guard Interval: #{@guard_interval}  Hierarchy: #{@hierarchy}\nVideo PID: #{@vpid}  Audio PID #{@apid}  Service ID: #{@sid}\n"
  end
end

class Code
        EOK = 0
        ENAVAIL = 1
end

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
      message = "Sorry: no entry..."
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
  if frequency.length == 0 then
    response = channels.to_s
  else
    frequency.each do |f| 
            channels[f].each {|l| (response ||= []) << l.to_s}
    end
  end
  return response
end

alias l list 

def mux(channels,*freq)  #Extra paramteres are simply ignored
  response = []
  if freq.length == 0 then
          response = channels.keys
  else 
          freq.each do |f| 
                  channels[f].each {|l| response << l.name}
          end
  end
  return response
end

alias m mux



def search(channels,*pattern)
  response = []
  if pattern.length >= 1 then
    (channels.values).each do |array_of_programs|
      array_of_programs.each do |program|
        if program.name.include?(pattern[0]) then 
           response << program.to_s
        end 
      end
    end
  end
  return response
end

alias s search

def live(channels)
        live_file = File.open(XML_PROGRAMS_FILE,'r')
        live_programs = Nokogiri::XML(live_file)
        live_file.close
        response = []
        live_programs.xpath("/program-list/program/program-name").each do |node|    # oppure dco.search.().each...
                        response << node.text
                end
        return response
end

def commanders(channels,line)
  command = line[0]
  if line.length > 1 then
    response = send command.to_sym, channels, *line[1..line.length-1]
  else
    response = send command.to_sym, channels
  end
end


def start_ruby_cli(channels,server,client,line)
        
        
  loop do
          request = Marshal::load(client)           
          line = request.split
          command=line[0]
          case
              when !(ALLOWED_COMMANDS.include? command) 
                err = Message.new(Code::ENAVAIL)
                err.fill("Command not available")
                Marshal::dump(err,client)
              when (HELP_COMMANDS.include? command)
                      msg = Message.new(Code::EOK)
                      msg.fill(helpers(line))
                      Marshal::dump(msg,client)
              else
                      msg = Message.new(Code::EOK)                    
                      msg.fill(commanders(channels,line))
                      Marshal::dump(msg,client)                     
  end
end

end


def start_telnet_cli(channels,server,client,line)      
   
    
    loop do
          command = line[0]
          case
            when !(ALLOWED_COMMANDS.include? command)
              client.puts  "Command not available\n" 
              client.flush
            when (HELP_COMMANDS.include? command)
              message = helpers(line)
              client.puts message 
              client.flush
            else
              response = commanders(channels,line)
              client.puts response 
              client.flush
          end
          
          client.close_write
          client = server.accept
          while (request = client.gets) == nil do 
            puts "Client quit unexpectedly"
            client.close
            client = server.accept
          end
          line = request.split
    end
end



# Begin main program

      channels = retrieve("channels.conf")

      server = TCPServer.open(PORT)
      STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil

begin
      client = server.accept
      puts "Connected to DVB Commander from #{client}"
      while (request = client.gets) == nil do 
        puts "Client quit unexpectedly"
        client.close
        client = server.accept
      end

      local, peer = client.addr, client.peeraddr 

      line = request.split
      command=line[0]
        
      case 
        when command == "RubyTerminal"
          msg=Message.new(Code::EOK)
          msg.fill("Connected to Ruby Terminal on #{peer[2]}:#{peer[1]} using local port #{local[1]}")
          STDOUT.puts msg
          Marshal::dump(msg,client)
          start_ruby_cli(channels,server,client,line)
        else
          start_telnet_cli(channels,server,client,line)
      end
      
rescue
      STDERR.puts "Connection to client closed"
      STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil
      raise    # uncomment to debug
      # retry     # comment to debug
end

  
  















