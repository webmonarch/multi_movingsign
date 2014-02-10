require 'thor'
require 'thread'
require 'socket'
require 'multi_movingsign/signs'
require 'multi_movingsign/testrc_loader'

module MultiMovingsign
  # http://stackoverflow.com/a/9439298
  class TeeIO < IO
    attr_accessor :destinations

    def initialize(*dests)
      self.destinations = dests
    end

    def puts(val)
      time = Time.now
      destinations.each do |d|
        d.puts "#{time}: #{val.to_s}"
        d.flush
      end
    end

    def write(val)
      destinations.each do |d|
        d.write val
        d.flush
      end
    end
  end

  # MultiMovingsign server command line interface
  class Server < Thor
  class_option :serverrc, :desc => 'Path to server persistent storage.  Defaults to ~/.multi_movingsign/server'
    desc 'start', 'Starts the MutliMovingsign server'
    def start
      TestRCLoader.load(options['testrc']) if options['testrc']

      # This impl is a hacky mess... FYI!
      FileUtils.mkdir_p server_settings_path

      lock_path = File.join(server_settings_path, "server.lock")
      File.open(lock_path, 'w') do |lock|
        raise "Cannot acquire lock! Is a server already running?" unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        lock.puts $$
        lock.flush

        mutex = Mutex.new

        # setup logging
        log_path = File.join(server_settings_path, "server.log")
        log = File.new(log_path, "a")
        $stdout = TeeIO.new($stdout, log)
        $stderr = TeeIO.new($stderr, log)

        signs = []

        page_keys = []
        page_solutions = {}
        page_index = 0
        alert = nil
        stop = nil

        Thread.new do
          begin
            Socket.unix_server_loop(server_socket_path) do |socket, address|
              puts "SOCKET LOOP!"

              begin
                msg = nil

                begin
                  msg, = socket.recvmsg_nonblock
                rescue IO::WaitReadable
                  if IO.select([socket], [], [], 5)
                    retry
                  else
                    raise TimeoutError, "Timeout in recvmsg_nonblock"
                  end
                end

                unless msg
                  $stderr.puts "Bogus unix_server_loop?"
                  next
                end

                lines = msg.lines.map { |l| l.rstrip }
                puts "Got UNIX message: #{lines.inspect}"

                version = lines.delete_at 0

                case command = lines.delete_at(0)
                  when 'add page'
                    name = lines.delete_at(0)
                    yaml = lines.join "\n"

                    solution = PageRenderer.new.render YAML.load(yaml), :count => signs.length
                    page_path = File.join(server_pages_path, "#{name}.yml")
                    File.open(page_path, "w") { |f| f.puts yaml }

                    mutex.synchronize do
                      page_solutions[name] = solution
                      page_keys << name unless page_keys.include? name

                      puts "Added #{name}!"

                      page_keys.delete 'nada'
                      page_solutions.delete 'nada'
                    end

                    socket.puts "okay"
                  when 'delete page'
                    name = lines.delete_at(0)

                    mutex.synchronize do
                      page_path = File.join(server_pages_path, "#{name}.yml")

                      FileUtils.rm(page_path, :force => true) if File.exists? page_path

                      page_keys.delete name
                      page_solutions.delete name
                    end

                    puts "Deleted #{name}"

                    socket.puts "okay"
                  when 'alert'
                    page_yaml = lines.join("\n")

                    mutex.synchronize do
                      condition_variable = ConditionVariable.new
                      alert = {"solution" => PageRenderer.new.render(YAML.load(page_yaml), :count => signs.length), 'condition_variable' => condition_variable}

                      puts "Signaling alert..."
                      condition_variable.wait mutex
                    end

                    socket.puts "okay"

                  when 'stop'
                    mutex.synchronize do
                      cv = ConditionVariable.new

                      stop = {'condition_variable' => cv}

                      cv.wait mutex
                    end

                    socket.puts "okay"
                  else
                    $stderr.puts "Unknown command '#{command}'"
                end
              rescue => e
                $stderr.puts "Exception in unix server loop"
                $stderr.puts e.message
                $stderr.puts e.backtrace.join "\n"
              ensure
                socket.close
                puts "SOCKET CLOSED"
              end
            end
          rescue => e
            $stderr.puts "UNIX socket loop raised!"
            $stderr.puts e.message
            $stderr.puts e.backtrace.join '\n'

            Thread::current.pi
          end
        end

        # Loop to allow reloaded
        loop do
          if stop
            puts "Outter loop stopping..."
            break
          end

          puts "Starting/Reloading!"

          # load sign configuration
          settings = Settings.load settings_path
          raise_no_signs unless settings.signs?

          mutex.synchronize do
            page_keys = []
            page_solutions = {}
            signs = Signs.new settings.signs

            # Load pages and solutions
            FileUtils.mkdir_p server_pages_path
            Dir.glob(File.join(server_pages_path, '*.yml')).sort.each do |path|
              puts "Loading #{path}"

              key = File.basename(path, File.extname(path))

              page_keys << key
              page_solutions[key] = PageRenderer.new.render YAML.load(File.read(path)), :count => signs.length
            end

            if page_keys.empty?
              page_keys << 'nada'
              page_solutions['nada'] = PageRenderer.new.render({'lines' => [{'prefix' => '', 'content' => ['No Pages']}, {'prefix' => '', 'content' => ['Configured']}]}, :count => signs.length)
            end
          end

          # Loop through pages
          loop do
            if stop
              puts "Inner loop stopping..."
              break
            end

            page_key = nil
            page_solution = nil

            mutex.synchronize do
              page_index = 0 if page_index >= page_keys.length || page_index < 0

              # check for alert
              if alert
                page_key = 'ALERT'
                page_solution = alert['solution']

                page_index -= 1

                # extract condition_variable
                condition_variable = alert['condition_variable']

                # clear alert
                alert = nil

                # signal that we got it!
                condition_variable.signal
              else
                page_key = page_keys[page_index]
                page_solution = page_solutions[page_key]
              end
            end

            puts "Sending page #{page_key}"
            signs.show_page_solution page_solution


            sleep_amount = page_solution['lines'] && page_solution['lines'] * 3 * 2 || 20
            sleep_amount = 20 if sleep_amount < 2

            sleep sleep_amount

            page_index += 1
          end
        end

        if cv = stop && stop['condition_variable']
          cv.signal
          sleep 1     # wait a bit for the CV recipient to finish before we do.
        end
      end
    end

    desc 'add-page', 'Adds a page to the server rotation'
    option :page, :required =>  true, :desc => "Path to page YAML"
    option :name, :required =>  true, :desc => "Name for the new file"
    def add_page
      exit send_socket_command_expect_ok ['v1', 'add page', options[:name], File.read(options[:page])]
    end

    desc 'delete-page', 'Deletes a page to the server rotation'
    option :name, :required =>  true, :desc => "Name for the new file"
    def delete_page
      exit send_socket_command_expect_ok ['v1', 'delete page', options[:name]]
    end

    desc 'alert', 'Sends a page to display as an alert'
    option :page, :required =>  true, :desc => "Path to page YAML"
    def alert
      exit send_socket_command_expect_ok ['v1', 'alert', File.read(options[:page])]
    end

    desc 'stop', 'Stops the running server'
    def stop
      exit send_socket_command_expect_ok ['v1', 'stop']
    end

    private

    def send_socket_command_expect_ok(args)
      UNIXSocket.open server_socket_path do |socket|
        send_socket_command(socket, args)
        puts "Sent message...awaiting reply..."

        (got = socket.gets) && got.strip == "okay" || false
      end
    end

    def send_socket_command(socket, args)
      socket.sendmsg args.join "\n"
      socket.flush
    end

    def server_socket_path
      File.join(server_settings_path, 'server.sock')
    end

    def server_settings_path
      options[:serverrc] || File.join(ENV['HOME'], '.multi_movingsign', 'server')
    end

    def server_pages_path
      File.join(server_settings_path, 'pages')
    end

    def settings_path
      options[:rc] || Settings.default_settings_path
    end
  end
end