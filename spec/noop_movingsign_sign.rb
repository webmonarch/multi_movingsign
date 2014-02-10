#
# Loaded by noop_movingsign_sign.yml
#
# This script makes all MovingsignApi::Sign methods a noop, allowing you to run/test/validate the CLI
# without having physical LED signs plugged in.
#
require 'movingsign_api/sign'

klass = Class.new do
  def double_movingsign_sign
    MovingsignApi::Sign.class_exec do
      @@mutex = Mutex.new

      class << self
        attr_accessor :calls
      end

      (MovingsignApi::Sign.public_instance_methods.to_a - Object.public_instance_methods.to_a - [:device_path]).each do |method|
        define_method(method) do |*args|
          @@mutex.synchronize do
            # sanitize arguments (since they contain invalid characters)
            sanitized_args = []
            args.each do |arg|
              if arg.kind_of? String
                sanitized_args << arg.encode("ASCII", :invalid => :replace, :undef => :replace, :replace => "?")
              end
            end

            self.calls << [self.device_path, method, sanitized_args]

            File.open('testrc.yml', 'w') do |f|
              f.write({'calls' => self.calls}.to_yaml)
            end
          end
        end
      end

      def calls
        self.class.calls
      end
    end

    MovingsignApi::Sign.calls = []
  end
end

klass.new.double_movingsign_sign