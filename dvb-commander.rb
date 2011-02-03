#! /usr/bin/ruby -w

require 'rubygems'
require 'socket'
require 'nokogiri'
include ObjectSpace

SERVER_IP_ADDRESS = "127.0.0.1"
PORT = "8100"
RUBY_TERMINAL = false
XML_PROGRAMS_FILE = "programs.xml"
XML_DEVICES_FILE = "device.xml"
DVB_FRONTEND_0 = "/dev/dvb/adapter0/frontend0"
DVB_DEMUX_0 = "/dev/dvb/adapter0/demux0"
DVB_DVR_0 = "/dev/dvb/adapter0/dvr0"

COMMANDER_COMMANDS = %w[help h list l search s mux m program p]
ALLOWED_STREAM_ACTIONS = %w[show live tune add remove]
ALLOWED_SERVER_ACTIONS = %w[status start stop restart]

HELP_COMMANDS = %w[help h]
SERVER_COMMANDS = %w[server]

class Programs
  attr_accessor :name, :frequency, :inversion, :bandwidth, :code_rate_hp, :code_rate_lp, :constellation, :transmission_mode, :guard_interval, :hierarchy_information, :apid, :vpid, :tpid
  
  def initialize(name, frequency, inversion, bandwidth, code_rate_hp, code_rate_lp, constellation, transmission_mode, guard_interval, hierarchy_information, vpid, apid, sid)
    @name = name
    @frequency = frequency
    @inversion = inversion
    @bandwidth = bandwidth
    @code_rate_hp = code_rate_hp 
    @code_rate_lp = code_rate_lp
    @constellation = constellation
    @transmission_mode = transmission_mode
    @guard_interval = guard_interval 
    @hierarchy_information = hierarchy_information
    @vpid = vpid                          # video pid
    @apid = apid                          # audio pid
    @sid = sid                            # service ID
  end
  
  def to_s
    "Name: #{@name}\nMUX: #{@frequency}\nInversion: #{@inversion}  Bandwidth: #{@bandwidth}  Code Rate HP: #{@code_rate_hp}  Code Rate LP: #{@code_rate_lp}\nConstellation: #{@constellation}  Transmission mode: #{@transmission_mode}  Guard Interval: #{@guard_interval}  Hierarchy Information: #{@hierarchy_information}\nVideo PID: #{@vpid}  Audio PID #{@apid}  Service ID: #{@sid}\n"
  end
end

class Device
        attr_accessor :frontend, :demux, :dvr, :frequency, :bandwidth, :constellation, :code_rate_hp, :code_rate_lp,  :transmission_mode, :guard_interval, :hierarchy_information, :inversion
        
        def initialize(frontend, demux, dvr, frequency, bandwidth, constellation, code_rate_hp, code_rate_lp, transmission_mode, guard_interval, hierarchy_information, inversion)
                @frontend = frontend    # DVB_FRONTEND_0
                @demux = demux          # DVB_DEMUX_0
                @dvr = dvr              # DVB_DVR_0
                @frequency = frequency
                @bandwidth = bandwidth  # 8
                @constellation = constellation # QAMAUTO
                @code_rate_hp = code_rate_hp # AUTO
                @code_rate_lp = code_rate_lp # AUTO
                @transmission_mode = transmission_mode # AUTO
                @guard_interval = guard_interval # AUTO
                @hierarchy_information = hierarchy_infromation # AUTO
                @inversion = inversion # AUTO
        end
end

class Code
        EOK = 0
        ENAVAIL = 1
        PID = 2
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

class Stream
        attr_accessor :program_name, :group, :ip_address, :port, :ttl, :sap_name
        def initialize(mux,program_name,ip_address,port,ttl,sap_name,sap_group)
                @mux = mux
                @program_name = program_name
                @ip_address = ip_address
                @port = port
                @ttl = ttl
                @sap_name = sap_name
                @sap_group = sap_group
        end
        def to_s
                "Stream name: #{@program_name}\n" + "Mux: #{@mux}\n" + "IP Address: #{@ip_address}\n" + "Port: #{@port}\n" + "TTL: #{@ttl}\n" + "SAP Name: #{@sap_name}\n" + "SAP Group: #{@sap_group}\n"
        end
        
end

class Task
      attr_reader :pid
      def initialize(*command_line)
            @command = command_line
      end
      
      def start
            @pid = Process.fork { exec @command.join(' ') }
            ObjectSpace.define_finalizer(self, self.class.finalize(@pid))
      end
      
      def stop(sig = 'TERM')
            Process.kill(sig, @pid)
            Process.wait
      end
      
      def restart
            stop
            start
      end
      
      # def self.Create(*args)
      #       p = Task.new([args])
      # end
      
     def self.finalize(pid)   # Class method used to finalize!!!! in case the oject gets garbage collected...
            proc { |id|  begin Process.kill('TERM',pid) rescue end } 
     end
      
end

######################################################################
################ Section of generic utilities ########################
######################################################################


def DVB_retrieve(file_in)   #generate a hash with key = mux frequency => [program]
    f = File.open("channels.conf")
    channels = Hash.new
    f.each do |line|
      s = line.split(/:/)
      program = Programs.new(*s)      
      (channels[program.frequency] ||= []) << program
    end
    return channels
end

def get_mux(channels,prog_name)
        mux = []
        (channels.keys).each do |freq|
                channels[freq].each do |p|
                        mux << freq if p.name == prog_name
                end
        end
        return mux
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
  msg = Message.new(Code::EOK)
  if line.length > 1 then
    msg.fill(send command.to_sym, "#{line[1..line.length-1]}")
  else
    msg.fill(send command.to_sym)
  end
  return msg
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
  msg = Message.new
  msg.fill(response)
  return msg
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
  msg = Message.new
  msg.fill(response)
  return msg

end

alias m mux

def search(channels,*pattern)
  pattern = pattern.join(' ')        
  response = []
  if pattern.length >= 1 then
    (channels.values).each do |array_of_programs|
      array_of_programs.each do |program|
        if program.name.include?(pattern) then 
           response << program.to_s
        end 
      end
    end
  end
  msg = Message.new
  msg.fill(response)
  return msg
end

alias s search
                                

def nowplaying(channels)
        live_file = File.open(XML_PROGRAMS_FILE,'r')
        live_programs = Nokogiri::XML(live_file)
        live_file.close
        
        live_streams = []
        live_programs.xpath("/program-list/program/program-name").each do |node|    # oppure dco.search.().each...
               # def initialize(mux,program_name,ip_address,sap_name,sap_group)
                        mux = get_mux(channels,node.text)
                        live_streams << Stream.new(mux,node.text,node.parent.xpath('./destination/ip-address').text,node.parent.xpath('./destination/port').text,node.parent.xpath('./destination/ttl').text,node.parent.xpath('./destination/sap/name').text,node.parent.xpath('./destination/sap/group-name').text)
                end
        puts live_streams
        return live_streams
end


def show(channels)
        
        live_file = File.open(XML_PROGRAMS_FILE,'r')
        live_programs = Nokogiri::XML(live_file)
        live_file.close
        
        response = []
        live_programs.xpath("/program-list/program/program-name").each do |node|    # oppure dco.search.().each...
                        response << "Streaming #{node.text} on multiacst group #{node.parent.xpath('./destination/ip-address').text}"
                end
        msg = Message.new(Code::EOK)
        msg.fill(response)    
        return msg    
end

def add(channels, *data)
        
end

def remove(channels, *data)
        # Incomplete... to be protected against misuses...
        live_file = File.open(XML_PROGRAMS_FILE,'r')
        live_programs = Nokogiri::XML(live_file)
        live_file.close
        
        stream_to_drop = data.join(" ")
        code = Code::ENAVAIL
        message = "Can't remove stream \"#{stream_to_drop}\""
        live_programs.xpath("/program-list/program/program-name").each do |node|    # oppure dco.search.().each...
                if node.text == stream_to_drop then
                        node.parent.remove
                        message = "Sussessfully removed stream \"#{stream_to_drop}\""
                        code = Code::EOK
                end
        end
        msg = Message.new(code)
        msg.fill(message)  
        
        live_file = File.open(XML_PROGRAMS_FILE,'w')
        live_programs.write_xml_to(live_file)
        live_file.close
        
        return msg      
        
end


def program(channels, *params)
        # input param channels is useless...
        
        
        action = params[0] if params.length != 0
        
        
        # live_streams = nowplaying(channels,live_programs)
        
        case
                when params.length == 1
                        if ALLOWED_STREAM_ACTIONS.include?(action) then
                                msg = send(action.to_sym,channels)
                                # msg = Message.new(Code::EOK)
                                # msg.fill(response)
                                
                        else
                                response = "Malformed Request"
                                msg = Message.new(Code::ENAVAIL)
                                msg.fill(response)
                        end
                        
                when params.length >= 1 
                        if ALLOWED_STREAM_ACTIONS.include?(action) then
                                msg = send(action.to_sym, channels, *params[1..params.length-1] )
                                # msg = Message.new(Code::EOK)
                                # msg.fill(response)                              
                        else 
                                response = "Malformed Request"
                                msg = Message.new(Code::ENAVAIL)
                                msg.fill(response)
                        end
                else
                        msg = Message.new()
                        msg.fill(nowplaying(channels).to_s)
        end
                
        return msg
        
end

alias p program

                
def commanders(channels,line)
  command = line[0]
  if line.length > 1 then
    send command.to_sym, channels, *line[1..line.length-1]
  else
    send command.to_sym, channels
  end
end

######################################################################
################ Section of Server Managers   ########################
######################################################################

def server_manager(streaming_server,line)        
        command = line[0]        
                
        if line.length > 1 then
           send command.to_sym, streaming_server, *line[1..line.length-1]
        else
           send command.to_sym, streaming_server
         end
end
        
def start(streaming_server)
        streaming_server[:dystreamd].start 
        streaming_server[:dytuned].start 
        msg = Message.new(Code::PID)
        msg.fill(streaming_server)
        return msg
end

def stop(streaming_server)
         
        streaming_server[:dystreamd].stop 
        streaming_server[:dytuned].stop 
        msg = Message.new(Code::PID)
        msg.fill(streaming_server)
        return msg
end

def restart(streaming_server)
        streaming_server[:dystreamd].restart 
        streaming_server[:dytuned].restart 
        msg = Message.new(Code::PID)
        msg.fill(streaming_server)
        return msg
end


def server(streaming_server, *params)
        
        action = params[0] if params.length != 0
        
        case
                when params.length == 1
                        if ALLOWED_SERVER_ACTIONS.include?(action) then
                                msg = send action.to_sym, streaming_server
                                
                        else
                                response = "Malformed Request"
                                msg = Message.new(Code::ENAVAIL)
                                msg.fill(response)
                        end
                        
                when params.length >= 1 
                        if ALLOWED_SERVER_ACTIONS.include?(action) then
                                msg = send action.to_sym, streaming_server, *params[1..params.length-1] 
                
                        else 
                                response = "Malformed Request"
                                msg = Message.new(Code::ENAVAIL)
                                msg.fill(response)
                        end
                else
                        msg = Message.new(Code::PID)
                        msg.fill(streaming_server)
        end
                
        return msg
        
end



######################################################################
################ Section of CLIs   ###################################
######################################################################




def start_ruby_cli(channels,server,client,streaming_server,line)
        
        
  loop do
          request = Marshal::load(client)           
          line = request.split
          command=line[0]
                   
          
          case
              when (COMMANDER_COMMANDS.include? command) 
                      response = commanders(channels,line)
                      Marshal::dump(response,client)
                      streaming_server = response.content if response.type == 'Code::PID'
                      
              when (HELP_COMMANDS.include? command)
                      Marshal::dump(helpers(line),client)
              
              when (SERVER_COMMANDS.include? command)                      
                      response = server_manager(streaming_server,line)
                      streaming_server = response.content if response.type == 'Code::PID'
                      Marshal::dump(response.to_s,client)
              else
                      err = Message.new(Code::ENAVAIL)
                      err.fill("Command not available")
                      Marshal::dump(err,client)
                      
           end
  end

end


def start_telnet_cli(channels,server,client,streaming_server,line)      
    loop do
          command = line[0]
          case
            when (HELP_COMMANDS.include? command)
              message = helpers(line)
              client.puts message 
              client.flush
            when (SERVER_COMMANDS.include? command)
                    response = server_manager(streaming_server,line)
                    streaming_server = response.content if response.type == 'Code::PID'
                    client.puts response 
                    client.flush
            when (COMMANDER_COMMANDS.include? command)
                    response = commanders(channels,line)
                    streaming_server = response.content if response.type == 'Code::PID'
                    client.puts response 
                    client.flush
            else
                      client.puts  "Command not available\n" 
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


######################################################################
################ Begin main program  #################################
######################################################################


      channels = DVB_retrieve("channels.conf")
      
      streaming_server = {}
      streaming_server[:dystreamd] = Task.new("xterm","-bg", "red")
      streaming_server[:dytuned] = Task.new("xterm","-bg", "blue")
      
      
      
      # live_file = File.open(XML_PROGRAMS_FILE,'r')
      #  live_programs = Nokogiri::XML(live_file)
      #  live_file.close
            
       
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
          start_ruby_cli(channels,server,client,streaming_server,line)
        else
          start_telnet_cli(channels,server,client,streaming_server,line)
      end
      
rescue
      STDERR.puts "Connection to client closed"
      STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil
      # raise    # uncomment to debug
      retry     # comment to debug
end

  
  















