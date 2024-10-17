require 'readline'
require 'open3'
require 'monitor'
require_relative "../lib/sonicpi/osc/osc"
require_relative "../paths"
require_relative "../lib/sonicpi/promise"
require 'mqtt'

## Very simple mqtt commandline music thing based on the repl that sam made
## Lots of stuff is hardcoded
## It also ensures the server is kept alive.

module SonicPi
  class Repl
    def initialize(init_code=nil)
      @log_output = true
      @server_started_prom = Promise.new
      @supercollider_started_prom = Promise.new
      @print_monitor = Monitor.new

      puts "daemon_stdout_and_err #{Paths.daemon_path}"

      daemon_stdin, daemon_stdout_and_err, daemon_wait_thr = Open3.popen2e Paths.ruby_path, Paths.daemon_path

      force_puts "-- Sonic Pi Daemon started with PID: #{daemon_wait_thr.pid}"
      force_puts "-- Log files are located at: #{Paths.log_path}"

      daemon_info_prom = Promise.new

      daemon_io_thr = Thread.new do
        daemon_stdout_and_err.each do |line|
          line = line.force_encoding("UTF-8")
          puts "line #{line}" 
          daemon_info_prom.deliver! line
          Thread.current.kill
        end
      end

      daemon_info = daemon_info_prom.get.split.map(&:to_i)

      puts "daemon_info #{daemon_info}"
      daemon_port = daemon_info[0]
      gui_listen_to_spider_port = daemon_info[1]
      gui_send_to_spider_port = daemon_info[2]
      scsynth_port = daemon_info[3]
      osc_cues_port = daemon_info[4]
      tau_port = daemon_info[5]
      tau_booter_port = daemon_info[6]
      daemon_token = daemon_info[7]

      force_puts "-- OSC Cues port: #{osc_cues_port}"

      daemon_zombie_feeder = Thread.new do
        osc_client = OSC::UDPClient.new("localhost", daemon_port)

        at_exit do
          force_puts ""
          force_puts "Killing the Sonic Pi Daemon...", :red
          force_puts "The Daemon has been vanquished!", :red
          force_puts ""
          force_puts "Farewell, artistic coder.", :cyan
          force_puts "May you live code and prosper...", :cyan
          print_ascii_art
          osc_client.send("/daemon/exit", daemon_token)
        end

        loop do
          osc_client.send("/daemon/keep-alive", daemon_token)
          sleep 5
        end
      end

      repl_eval_osc_client = OSC::UDPClient.new("localhost", gui_send_to_spider_port)

      spider_incoming_osc_server = OSC::UDPServer.new(gui_listen_to_spider_port)
      add_incoming_osc_handlers!(spider_incoming_osc_server)

      force_puts "-- Waiting for Sonic Pi to boot..."
      Thread.new do
        while ! @server_started_prom.delivered?
          begin
            repl_eval_osc_client.send("/ping", daemon_token, "Hello from the REPL!")
          rescue Errno::ECONNREFUSED
          end
          sleep 0.5
        end
      end


      @server_started_prom.get
      @supercollider_started_prom.get
      force_puts "-- Sonic Pi Server started"
      force_puts "-- Setting amplitude to 2"
      repl_eval_osc_client.send("/mixer-amp", daemon_token, 2, 1)
      print_ascii_art
      repl_eval_osc_client.send("/run-code", daemon_token, init_code) if init_code
      force_puts ""
      force_puts "Welcome to a demo of mqtt and commandline sonic pi. Just listen!"
      force_puts "==="
      force_puts ""

      #libby
      # first link up the sound card
      # this is supposed to happen in the daemon.rb (line 1314) but assumes HDMI.
      # could def be less hardcoded
      # got it using pw-link --output --id
      # and checked with pw-dot. You can only link them when supercollider is running

#      `pw-link SuperCollider:out_1 alsa_output.usb-1395_Sennheiser_SP_20_5060490137021168-00.analog-stereo:playback_FL`
#      `pw-link SuperCollider:out_2 alsa_output.usb-1395_Sennheiser_SP_20_5060490137021168-00.analog-stereo:playback_FR`
      `pw-link SuperCollider:out_1 alsa_output.usb-0d8c_C-Media_USB_Headphone_Set-00.analog-stereo:playback_FL`
      `pw-link SuperCollider:out_2 alsa_output.usb-0d8c_C-Media_USB_Headphone_Set-00.analog-stereo:playback_FR`

      # make a noise to show we are up and running
      repl_eval_osc_client.send("/run-code", daemon_token, "play 60")

      # more hardcoded stuff
      # the xxx are an ip address
      MQTT::Client.connect('xxx.xxx.xxx.xxx') do |c|
      # If you pass a block to the get method, then it will loop
         c.get('cube/music') do |topic,message|
            puts "#{topic}: #{message}"
            key_start = 26
            # more cheery
            #key_of_C = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84, 86, 88, 89, 91, 93, 95, 96]
            # more doomy   
            key_of_C = [26,28,29,31,33,35,36,38,40,41,43,45,47,48,50,52,53,55,57,59,60]
            raw_data_min = 50
            raw_data_max = 1500
            factor = (raw_data_max - raw_data_min)/(key_of_C.max - key_of_C.min)
            puts "factor #{factor}, message.strip #{message.strip}, message.strip #{message.strip.to_i}"
            d = message.strip.to_i/factor
            if(d != 0)
               # adjust to our key starting point
               # and find the closest key number
               d = d + key_start
               z1 = key_of_C.find { |e| e == d }
               z2 = key_of_C.reverse.find { |e| e < d } 
               z3 = key_of_C.find { |e| e > d }
               closest_or_exact_number = z1 || z3 || z2

               # play some stuff
               Thread.new do
                 a = 10
                 20.times do
                     buf = "with_fx :reverb do\n  sample :elec_plip, amp: #{a}\n  play #{closest_or_exact_number}, release: 3\nend" 
                     puts buf
                     repl_eval_osc_client.send("/run-code", daemon_token, buf)
                     if(a>0.7)
                       a = a - 0.7
                     else
                       a = 0.1
                     end
                     sleep 2
                 end
               end

            end
         end
      end
    end

    def print_message(msg)
      case msg[0]
      when 0
        async_puts msg[1], :green
      when 1
        async_puts msg[1], :cyan
      else
        async_puts msg[1], :white
      end
    end

    def print_multi_message(msg)
      job_id = msg[0]
      thread_name = msg[1]
      time = msg[2]
      size = msg[3]
      msgs = msg[4..-1]
      if thread_name == "\"\""
        async_puts "Run #{job_id}, Time #{time}", :bold
      else
        async_puts "Run #{job_id}, Thread #{thread_name}, Time #{time}", :bold
      end
      last_msg = msgs.pop
      _last_colour = msgs.pop
      msgs.each_cons(2) do |colour, msg|
        print_message [1, "├─ #{msg}"]
      end
      print_message [1, "└─ #{last_msg}"]
    end

    def async_puts(msg, colour = :white)
      @print_monitor.synchronize do
        print "\r#{' ' * (Readline.line_buffer.length + 3)}\r"
        repl_puts msg, colour
        begin
          Readline.redisplay
        rescue
        end
      end
    end

    def repl_puts(msg, colour = :white)
      if @log_output
        force_puts msg, colour
      end
    end

    def force_puts(msg, colour = :white)
      @print_monitor.synchronize do
        case colour
        when :red
          puts "\e[31m#{msg}\e[0m"
        when :green
          puts "\e[32m#{msg}\e[0m"
        when :blue
          puts "\e[34m#{msg}\e[0m"
        when :yellow
          puts "\e[33m#{msg}\e[0m"
        when :magenta
          puts "\e[35m#{msg}\e[0m"
        when :cyan
          puts "\e[36m#{msg}\e[0m"
        when :bold
          puts "\e[1m#{msg}\e[22m"
        else
          puts msg
        end

      end
    end


    def add_incoming_osc_handlers!(osc)
      osc.add_method("/scsynth/info") do |msg|
        async_puts "SuperCollider Info:", :blue
        async_puts "===================", :blue
        async_puts ""
        async_puts msg[0], :blue
        @supercollider_started_prom.deliver! true
      end

      osc.add_method("/version") do |msg|
        async_puts "Sonic Pi Version: #{msg[0]}"
        async_puts msg[1..-1].inspect
      end

      osc.add_method("/incoming/osc") do |msg|
        time = msg[0]
        id = msg[1]
        address = msg[2]
        args = msg[3]

        async_puts "Cue - #{time} - #{id} - #{address} - #{args}"
      end

      osc.add_method("/error") do |msg|
        job_id = msg[0]
        description = msg[1]
        trace = msg[2]
        line_number =  msg[3]

        force_puts "Error on line #{line_number} for Run #{job_id}", :red
        force_puts "  #{description}", :red
        force_puts "  #{trace}", :red
      end

      osc.add_method("/syntax_error") do |msg|
        job_id = msg[0]
        description = msg[1]
        error_line = msg[2]
        line_number =  msg[3]

        force_puts "Syntax error on line #{line_number} for Run #{job_id}", :blue
        force_puts "  #{error_line}", :blue
        force_puts "  #{description}", :blue
      end

      osc.add_method("/log/info") do |msg|
        print_message(msg)
      end

      osc.add_method("/log/multi_message") do |msg|
        return if msg == ""

#        if msg.is_a?(Array)
          #print_multi_message(msg)
 #       end
      end

      osc.add_method("/runs/all-completed") do
      end

      osc.add_method("midi/out-ports") do |msg|
        async_puts "MIDI OUT PORTS: #{msg[0]}"
      end

      osc.add_method("midi/in-ports") do |msg|
        async_puts "MIDI IN PORTS: #{msg[0]}"
      end

      osc.add_method("/exited") do
        async_puts "Sonic Pi has closed"
      end

      osc.add_method("/ack") do
        @server_started_prom.deliver! true
      end
    end

    def print_ascii_art
      force_puts '

                                ╘
                         ─       ╛▒╛
                          ▐╫       ▄█├
                   ─╟╛      █▄      ╪▓▀
         ╓┤┤┤┤┤┤┤┤┤  ╩▌      ██      ▀▓▌
          ▐▒   ╬▒     ╟▓╘    ─▓█      ▓▓├
          ▒╫   ▒╪      ▓█     ▓▓─     ▓▓▄
         ╒▒─  │▒       ▓█     ▓▓     ─▓▓─
         ╬▒   ▄▒ ╒    ╪▓═    ╬▓╬     ▌▓▄
         ╥╒   ╦╥     ╕█╒    ╙▓▐     ▄▓╫
                    ▐╩     ▒▒      ▀▀
                         ╒╪      ▐▄

       _____             __        ____  __
      / ___/____  ____  /_/____   / __ \/_/
      \__ \/ __ \/ __ \/ / ___/  / /_/ / /
     ___/ / /_/ / / / / / /__   / ____/ /
    /____/\____/_/ /_/_/\___/  /_/   /_/

   The Live Coding Music Synth for Everyone

            http://sonic-pi.net

      '
    end
  end
end


SonicPi::Repl.new()
