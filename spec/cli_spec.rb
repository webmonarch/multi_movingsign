require 'spec_helper'
require 'tempfile'
require 'timeout'

describe MultiMovingsign::Cli do
  let(:temp_settings_file) { File.join(Dir.mktmpdir('test-settings-'), 'test-settings.yml') }
  let(:multi_movingsign_exe) { Gem.bin_path('multi_movingsign', 'multi_movingsign') }

  # Testing magic, @see TestRCLoader and {file:spec/noop_movingsign_sign.rb}
  let(:testrc_noop) { "spec/noop_movingsign_sign.yml" }
  let(:testrc_results) { Hashie::Mash.new YAML::load(File.read('testrc.yml')) }

  let(:setup_command_results) { execute("#{multi_movingsign_exe} setup --rc #{temp_settings_file} --signs /dev/ttyUSB0") }

  describe "'setup' command" do
    it "No Options" do
      expect(execute("#{multi_movingsign_exe} setup")).to be_success
    end

    describe "--signs /dev/ttyUSB0" do
      let (:execution_results) { execute("#{multi_movingsign_exe} setup --rc #{temp_settings_file} --signs /dev/ttyUSB0") }
      let (:hash) { YAML.load(File.read(temp_settings_file)) }

      before(:each) do
        execution_results
      end

      it "Succeeds" do
        expect(execution_results).to be_success
      end

      it "Settings File Exists" do
        expect(File.exists? temp_settings_file).to be_true
      end

      it "Settings File Contains ttyUSB0" do
        expect(File.read(temp_settings_file)).to include 'ttyUSB0'
      end
    end
  end

  describe "'settings' command" do
    let (:settings_command_results) { execute("#{multi_movingsign_exe} settings --rc #{temp_settings_file}") }

    describe "Without Setup" do
      before(:each) do
        settings_command_results
      end

      it "Succeeds" do
        expect(settings_command_results).to be_success
      end

      it "Containts 'Signs (0)'" do
        expect(settings_command_results.stdout).to include 'Signs (0)'
      end
    end

    describe "With Setup" do
      before(:each) do
        setup_command_results
        settings_command_results
      end

      it "Succeeds" do
        expect(settings_command_results).to be_success
      end

      it "Containts 'ttyUSB0'" do
        expect(settings_command_results.stdout).to include 'ttyUSB0'
      end

      it "Containts 'Signs (1)'" do
        expect(settings_command_results.stdout).to include 'Signs (1)'
      end
    end
  end

  describe "'show-identity' command" do
    let (:show_identity_command_results) { execute("#{multi_movingsign_exe} show-identity --rc #{temp_settings_file} --testrc #{testrc_noop}") }

    before(:each) do
      setup_command_results

      double_movingsign_sign
      show_identity_command_results
    end

    it "Succeeds" do
      expect_command_success show_identity_command_results
    end

    it "Signs Calls == 1" do
      expect(testrc_results.calls.length).to eq 1
    end
  end

  describe "'server' subcommand" do
    let (:server_configuration_directory) { Dir.mktmpdir "multi_movingsign_server-" }
    let (:server_thread) { thread = Thread.new { execute("#{multi_movingsign_exe} server start --rc #{temp_settings_file} --serverrc #{server_configuration_directory} --testrc #{testrc_noop}") }; sleep 1; thread }

    before(:each) do
      setup_command_results
    end

    describe "'start' command" do
      before(:each) do
        double_movingsign_sign
        server_thread
      end

      after(:each) do
        server_thread.kill
        server_thread.join
      end

      it "Is Alive?" do
        expect(server_thread).to be_alive
      end

      it "Creates PID File" do
        expect(File.exists? File.join(server_configuration_directory, 'server.lock')).to be_true
      end

      it "Creates SOCK File" do
        expect(File.exists? File.join(server_configuration_directory, 'server.sock')).to be_true
      end
    end

    describe "'stop' command" do
      let (:server_stop_results) { execute "#{multi_movingsign_exe} server stop --rc #{temp_settings_file} --serverrc #{server_configuration_directory}" }

      before(:each) do
        double_movingsign_sign
        server_thread

        timeout(60) { server_stop_results }
      end

      after(:each) do
        server_thread.kill
        server_thread.join
      end

      it "Shuts Down Server" do
        sleep 3

        expect(server_thread).to_not be_alive
        expect(server_stop_results).to be_success
      end
    end

    pending "'add-page' command"
    pending "'delete-page' command"
    pending "'alert' command"
  end

  #it "show-page command"
  #it "show-page succeeds"
  #it "show-page sends show_text on each display"
  #it "server"
  #multi_movingsign server add-page --name=NAME --page=PAGE  # Adds a page to the server rotation
  #multi_movingsign server alert --page=PAGE                 # Sends a page to display as an alert
  #multi_movingsign server delete-page --name=NAME           # Deletes a page to the server rotation
  #multi_movingsign server help [COMMAND]                    # Describe subcommands or one specific subcommand
end