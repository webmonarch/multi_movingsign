require 'tempfile'
require 'hashie/mash'

module ExecutableHelpers
  # Executes a given command string, collecting both stdout and stderr, along with the exit status.
  # @return [ExecutationResult] container of the execution results
  def execute(command)
    out_path = File.join(Dir.mktmpdir('execute-'), 'stdout.log')
    out_file = File.open(out_path, 'w')

    pid = Kernel.spawn(command, [:out, :err] => out_file.fileno, :in => :close)
    RSPEC_LOGGER.info "[#{pid}] Executed '#{command}' > #{out_file.path}"
    Process.waitpid(pid)

    out_file.flush
    out_file.close

    out = File.read out_file.path

    result = ExecutationResult.new
    result.status = $?
    result.stdout = out

    result
  end

  # This never really worked well for testing.  Keeping for now.
  ## Executes a given block in this procress
  #def execute_in_process(&block)
  #  exit_status = 1
  #  stdout = ""
  #
  #  stdout = capture do
  #    begin
  #      begin
  #        yield
  #      rescue ScriptError => e
  #        report_raise e
  #        exit 1
  #      rescue SignalException => e
  #        report_raise e
  #        exit 1
  #      rescue StandardError => e
  #        report_raise e
  #        exit 1
  #      end
  #    rescue SystemExit => e
  #      exit_status = e.status
  #    else
  #      exit_status = 0
  #    end
  #  end
  #
  #  status_double = Object.new
  #  status_double.instance_exec(exit_status) do |status|
  #    @exit_status = status
  #
  #    def success?
  #      @exit_status == 0
  #    end
  #
  #    def exitstatus
  #      @exit_status
  #    end
  #  end
  #
  #  result = ExecutationResult.new
  #  result.status = status_double
  #  result.stdout = stdout
  #
  #  result
  #end

  def expect_command_success(command_results)
    expect(command_results).to be_success, "Expected command successs but it failed.  Got: \n#{command_results.stdout}"
  end

  def report_raise(e)
    $stderr.puts e.message
    $stderr.puts e.backtrace.join "\n"
  end

  def capture(&code)
    out = StringIO.new

    og_stdout = $stdout
    og_stderr = $stderr
    begin
      $stdout = out
      $stderr = out

      yield
    ensure
      $stdout = og_stdout
      $stderr = og_stderr
    end

    out.string
  end

  # Container for the execution results returned by {ExecutableHelpers::execute}
  class ExecutationResult
    # Execution status (as returned by $?)
    attr_accessor :status
    # STDOUT + STDERR as a string
    attr_accessor :stdout

    def success?
      self.status.success?
    end
  end
end