#! /usr/bin/ruby -w

require 'rubygems'
require 'socket'
require 'nokogiri'
SERVER_IP_ADDRESS = "127.0.0.1"
PORT = "8100"
RUBY_TERMINAL = false
XML_PROGRAMS_FILE = "programs.xml"
XML_DEVICES_FILE = "device.xml"
DVB_FRONTEND_0 = "/dev/dvb/adapter0/frontend0"
DVB_DEMUX_0 = "/dev/dvb/adapter0/demux0"
DVB_DVR_0 = "/dev/dvb/adapter0/dvr0"

ALLOWED_COMMANDS = %w[help h list l search s mux m program p]
ALLOWED_STREAM_ACTIONS = %w[show live tune add remove]

HELP_COMMANDS = %w[help h]

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

def get_mux(channels,prog_name)
        mux = []
        (channels.keys).each do |freq|
                channels[freq].each do |p|
                        mux << freq if p.name == prog_name
                end
        end
        return mux
end
                                

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


def show()
        
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

def add(*data)
        
end

def remove(*data)
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
        
        # To Do: missing relaunch dvbstream!!!
        return msg      
        
end


def program(channels, *params)
        # input param channels is useless...
        
        
        action = params[0] if params.length != 0
        
        
        # live_streams = nowplaying(channels,live_programs)
        
        case
                when params.length == 1
                        if ALLOWED_STREAM_ACTIONS.include?(action) then
                                msg = send(action.to_sym)
                                # msg = Message.new(Code::EOK)
                                # msg.fill(response)
                                
                        else
                                response = "Malformed Request"
                                msg = Message.new(Code::Code::ENAVAIL)
                                msg.fill(response)
                                
                        end
                when params.length >= 1 
                        if ALLOWED_STREAM_ACTIONS.include?(action) then
                                msg = send(action.to_sym, *params[1..params.length-1] )
                                # msg = Message.new(Code::EOK)
                                # msg.fill(response)                              
                        else 
                                response = "Malformed Request"
                                msg = Message.new(Code::Code::ENAVAIL)
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
                      Marshal::dump(helpers(line),client)
                      
              else
                      Marshal::dump(commanders(channels,line),client)
                      
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

      channels = DVB_retrieve("channels.conf")
      
      
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
          start_ruby_cli(channels,server,client,line)
        else
          start_telnet_cli(channels,server,client,line)
      end
      
rescue
      STDERR.puts "Connection to client closed"
      STDOUT.puts "DVB Commander listenining on TCP port #{PORT}" if server != nil
      # raise    # uncomment to debug
      retry     # comment to debug
end

  
  















