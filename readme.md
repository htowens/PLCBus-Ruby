PLCBus-Ruby is a simple script that can be executed from the command line to control PLCBus devices. It should work with either version of the PLCBus USB controller (1141 or 1141+). I have not tested it with the serial controller.

The commands can be sent directly from the command line, with no need to run the script as a server.

Before using the script, it will be necessary to edit lines 14 and 15 in order to set the script up for your controller and user code.

    Usage: ruby plcbus.rb -d <device> -c <command> -d1 [data1] -d2 [data2]
        -d, --device DEVICE              The device to send the command to
        -c, --command COMMAND            The command to send to the device
            --data1 DATA1                The optional data1 parameter
            --data2 DATA2                The optional data2 parameter
        -h, --help                       Display this screen