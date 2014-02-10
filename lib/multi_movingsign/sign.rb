require 'movingsign_api'
require 'multi_movingsign/sign'

module MultiMovingsign
  # Represents an individual Movingsign LED sign being driven
  class Sign
    attr_accessor :path

    def initialize(path)
      self.path = path
    end

    def self.load(hash)
      path = hash['path'] || (raise InvalidInputError, "path key not specified")

      self.new path
    end

    def show_text(text, options = {})
      sign.show_text text, options
    end

    def set_sound(on)
      sign.set_sound on
    end

    def to_hash
      {'path' => self.path}
    end

    private

    def sign
      MovingsignApi::Sign.new self.path
    end
  end
end