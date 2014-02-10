require 'yaml'
require 'hashie'
require 'multi_movingsign/sign'

module MultiMovingsign
  # Settings wrapper (reads/saves from/to YAML file via {load} / {#dump})
  class Settings
    attr_accessor :mash

    # Constructs a new {Settings} instance from settings saves in the specified YAML file
    def self.load(path)
      if File.exists? path
        self.new YAML.load(File.read(path))
      else
        self.new({})
      end
    end

    def initialize(hash = {})
      self.mash = Hashie::Mash.new hash
    end

    # Returns an array of the configured {Sign}s
    def signs
      self.mash.signs ||= []

      self.mash.signs.map { |hash| Sign.load(hash) }
    end

    # +true+ if any signs are configured
    def signs?
      ! self.signs.empty?
    end

    # Sets the list of conifgured {Sign}s via an array of serial port paths
    #
    # @example
    #   settings.sign_paths = ['/dev/ttyUSB0', '/dev/ttyUSB1']
    def sign_paths=(paths)
      self.mash.signs = paths.map { |path| {'path' => path} }
    end

    # Serializes (dumps) the settings into the specified YAML file
    def dump(path)
      File.open(path, 'w') do |f|
        f.write(self.mash.to_hash.to_yaml)
      end
    end

    # Default path for the settings YAML file
    def self.default_settings_path
      File.join(ENV['HOME'], '.multi_movingsign.yml')
    end
  end
end