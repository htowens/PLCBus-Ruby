require 'rubygems'
require 'serialport'
require 'optparse'
require 'pp'

# Add a sum method to the array class so we can sum array elements more elegantly
class Array
    def sum
        self.inject{|sum,x| sum + x }
    end
end

# Create system variables
@serial_device = "/dev/ttyUSB0"
@user_code = 0xA9

# Create an array to hold the command line options
options = {}

# Set the default options
options[:device] = nil
options[:command] = nil
options[:data1] = 0x00
options[:data2] = 0x00

# Parse the command line options 
optparse = OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: ruby plcbus.rb -d <device> -c <command> -d1 [data1] -d2 [data2]"
  # Set the device to control
  opts.on( '-d', '--device DEVICE', 'The device to send the command to' ) do |device|
    options[:device] = device
  end
  # Set the command to send to the device
  opts.on( '-c', '--command COMMAND', 'The command to send to the device' ) do |command|
    options[:command] = command
  end
  # Set the optional data1 parameter
  opts.on( '--data1 DATA1', 'The optional data1 parameter' ) do |data1|
    options[:data1] = data1
  end
  # Set the optional data1 parameter
  opts.on( '--data2 DATA2', 'The optional data2 parameter' ) do |data2|
    options[:data2] = data2
  end
  # Show the helpfile
  opts.on_tail( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

# Parse the options
optparse.parse!

# DEBUG: print the options
#pp "Options:", options
#pp "ARGV:", ARGV

raise "Error: Device and Command are required options" if (options[:device] == nil || options[:command] == nil)

# Set variables using the array values
@device = options[:device]
@command = options[:command]
@data1 = options[:data1].to_i
@data2 = options[:data2].to_i

# Create arrays of commands that require Data1 and Data2 to be specified
@data1_commands = [
  "DIM",
  "BRIGHT",
  "BLINK",
  "PRESET_DIM",
  "STATUS_ON",
  "R_MASTER_ADDR_SETUP",
  "T_MASTER_ADDR_SETUP",
  "SCENE_ADDR_SETUP",
  "GET_SIGNAL_STRENGTH", 
  "GET_NOISE_STRENGTH"
  ]

  @data2_commands = [
  "PRESET_DIM",
  "STATUS_ON",
  "R_MASTER_ADDR_SETUP",
  "T_MASTER_ADDR_SETUP",
  "SCENE_ADDR_SETUP",
  "GET_SIGNAL_STRENGTH", 
  "GET_NOISE_STRENGTH"
  ]
  
if @data1_commands.include?(@command) && options[:data1] == nil
  raise "Error: Data1 is required for command " + @command
elsif @data2_commands.include?(@command) && options[:data2] == nil
  raise "Error: Data2 is required for command " + @command
end

# Set up the conversion from command to hex
# NOTE: Ensure that no 2 items in this array have duplicate hex values (invert is used later, so data will be lost if there are duplicates)
@command_to_hex = {
  "ALL_UNITS_OFF"	          => 0x00,
	"ALL_LIGHTS_ON"	          => 0x01,
	"ON"			                => 0x02,
	"OFF"			                => 0x03,
	"DIM"		      	          => 0x04,
	"BRIGHT"		              => 0x05,
	"ALL_LIGHTS_OFF"	        => 0x06,
	"ALL_USER_LIGHTS_ON"	    => 0x07,
	"ALL_USER_UNITS_OFF"	    => 0x08,
	"ALL_USER_LIGHTS_OFF"	    => 0x09,
	"BLINK"			              => 0x0a,
	"FADE_STOP"		            => 0x0b,
	"PRESET_DIM"		          => 0x0c,
	"STATUS_ON"		            => 0x0d,
	"STATUS_OFF"		          => 0x0e,
	"STATUS_REQUEST"	        => 0x0f,
	"R_MASTER_ADDR_SETUP"	    => 0x10,
	"T_MASTER_ADDR_SETUP"	    => 0x11,
	"SCENE_ADDR_SETUP"	      => 0x12,
	"SCENE_ADDR_ERASE"	      => 0x13,
	"ALL_SCENES_ADDR_ERASE"	  => 0x14,
	"GET_SIGNAL_STRENGTH"	    => 0x18,
	"GET_NOISE_STRENGTH"	    => 0x19,
	"REPORT_SIGNAL_STRENGTH"  => 0x1a,
	"REPORT_NOISE_STRENGTH"   => 0x1b,
	"GET_ALL_ID_PULSE"	      => 0x1c,
	"GET_ON_ID_PULSE"	        => 0x1d,
	"REPORT_ALL_ID_PULSE"	    => 0x1e,
	"REPORT_ON_ID_PULSE"	    => 0x1f
}

# Create an inverted array to allow hex to be converted back to a command
@hex_to_command = @command_to_hex.invert

# Create an array of the commands that require an ACK to be requested
@ack_commands = [
  "ON", 
  "OFF", 
  "DIM", 
  "BRIGHT", 
  "BLINK", 
  "FADE_STOP", 
  "PRESET_DIM", 
  "R_MASTER_ADDR_SETUP", 
  "T_MASTER_ADDR_SETUP", 
  "ALL_SCENES_ADDR_ERASE", 
  "GET_SIGNAL_STRENGTH", 
  "GET_NOISE_STRENGTH"
  ]
  
# Convert the device address to hex
@housecode = @device[0].chr.tr('A-P', '0-15').to_i
@devicecode = @device.reverse.chop.reverse.to_i - 1
@device_int = @housecode + @devicecode

# Convert the command passed as a command line option to hex  
@hex_command = @command_to_hex[@command]

# If the command requires an ACK, adjust the hex value accordingly
@hex_command = @hex_command + 0x20 if @ack_commands.include?(@command)

# Set up the serial ports (a separate one for reading and writing to avoid any packet loss)
@port_read = SerialPort.new(@serial_device, 9600)
@port_read.modem_params = ({"parity"=>0, "baud"=>9600, "stop_bits"=>1, "data_bits"=>8})
@port_read.read_timeout = (900)
@port_write = SerialPort.new(@serial_device, 9600)
@port_write.modem_params = ({"parity"=>0, "baud"=>9600, "stop_bits"=>1, "data_bits"=>8})

# Prepare a packet based on the command requested
# DEBUG: print the values of the variables
#puts "User code: " + @user_code.to_s
#puts "Device: " + @device_int.to_s
#puts "Command: " + @hex_command.to_s
#puts "Data1: " + @data1.to_s
#puts "Data2: " + @data2.to_s
@packet = [0x02, 0x05, @user_code, @device_int, @hex_command, @data1, @data2, 0x03].pack('C*')

# Write the packet to the serial port and wait for a response
def send_command
  # Send the packet 3 times (loop will break early if command is successful and response is received)
  3.times {
    @port_write.write @packet
    @returned_packet = @port_read.read
    #DEBUG: print the received packet
    #puts @returned_packet.unpack('C*')
    @parsed_response = parse_response(@returned_packet)
    if @returned_packet != nil && @parsed_response
      puts @parsed_response
      break
    elsif @returned_packet != nil && @parsed_response == false
      "A packet was received, but it was not a valid response"
    else
      puts "No response received"
    end
    # Wait 125ms before sending the packet again
    sleep(1.0/8.0)
  }
end

def parse_response(packet)
  packet_array = packet.unpack('C*')
  if packet_array.length == 18 &&
    packet_array[9] == 0x02 &&
    (packet_array.sum % 0x100 == 0 || packet_array[17] == 0x03) &&
    (packet_array[10] == 0x06) &&
    (packet_array[11] == @user_code) &&
    (packet_array[12] == @device_int) &&
    (packet_array[13] == @hex_command)
    return "Device " + @device + " received command and reported status " + @hex_to_command[packet_array[13] - 32] + ", with Data1 " + 
      packet_array[14].to_s + " and Data2 " + packet_array[15].to_s
  else
    return false
  end
end

send_command

