require 'thor'
require 'multi_movingsign/server'
require 'multi_movingsign/settings'
require 'multi_movingsign/signs'

module MultiMovingsign
  # Command line interface to MultiMovingsign
  class Cli < Thor
    class_option :rc, :desc => 'Path the persistent settings file. Defaults to: ~/.multi_movingsign.yml'
    class_option :testrc, :desc => 'Path to a script loaded BEFORE execution (used for testing)', :hide => true

    desc 'setup', "Setup available Movingsign LED signs and preferences"
    option :signs, :type => :array, :desc => "List of Movingsign LED board serial ports"
    def setup
      if signs = options[:signs]
        settings = Settings.load settings_path
        settings.sign_paths = signs

        settings.dump settings_path
      end
    end

    desc 'settings', 'Prints settings to terminal'
    def settings
      settings = Settings.load settings_path

      puts "Signs (#{settings.signs.length}): #{settings.signs.map { |s| s.path }.join(' ')}"
    end

    desc 'show-identity', 'Show sign identifying information on all signs'
    def show_identity
      TestRCLoader.load(options['testrc']) if options['testrc']

      settings = Settings.load settings_path

      # validate we have signs
      raise_no_signs unless settings.signs?

      signs = Signs.new settings.signs

      signs.show_identity
    end

    desc 'show-page', 'Renders the specified page to the configured signs'
    option :page, :required => true, :desc => "YAML containing page definition"
    def show_page
      TestRCLoader.load(options['testrc']) if options['testrc']

      settings = Settings.load settings_path
      raise_no_signs unless settings.signs?

      signs = settings.signs

      page = YAML.load(File.read(options[:page]))

      renderer = PageRenderer.new
      solution = renderer.render(page, :count => signs.length)

      threads = []
      solution['signs'].each_with_index do |hash, i|
        threads << Thread.new do
          signs[i].show_text hash['content'], :display_pause => 3
        end
      end
      threads.each { |t| t.join }
    end

    desc 'server SUBCOMMAND ...ARGS', 'Run or manipuate the MultiMovingsign server'
    subcommand 'server', Server

    private

    def settings_path
      options[:rc] || Settings.default_settings_path
    end

    def raise_no_signs
      raise InvalidInputError, "No signs specified.  Please run setup with the --signs option."
    end
  end
end