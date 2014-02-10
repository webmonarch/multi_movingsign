module MultiMoviginsignDoubles
  # Overrides MovingsignApi::Sign recording all calls to it's methods (for testing/validation)
  def double_movingsign_sign
    MovingsignApi::Sign.class_exec do
      @@mutex = Mutex.new

      class << self
        attr_accessor :calls
      end

      (MovingsignApi::Sign.public_instance_methods.to_a - Object.public_instance_methods.to_a - [:device_path]).each do |method|
        define_method(method) do |*args|
          @@mutex.synchronize do
            self.calls << [self.device_path, method, args]
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