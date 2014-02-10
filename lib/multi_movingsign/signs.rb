require 'multi_movingsign/sign'

module MultiMovingsign
  # Represents a collection of {Sign}s that you want to drive in unison
  class Signs
    attr_accessor :signs

    # @param options [Array<Sign>] an array of {Sign} instances
    def initialize(options)
      if options.kind_of?(Array) && options.all? { |v| v.kind_of?(Sign) }
        self.signs = options
      else
        raise InvalidInputError, "Invalid Signs#new options"
      end
    end

    # Sends/show the specified page solution on the signs
    def show_page_solution(solution)
      threads = []
      solution['signs'].each_with_index do |hash, i|
        threads << Thread.new do
          # Prepend "\xFDB" to set color to HIGH RED
          # .gsub("\n", "\x7F") - replace new lines with the sign specific newline character
          text = "\xFDB" + hash['content'].gsub("\n", "\x7F")
          self.signs[i].show_text text, :display_pause => 3
        end
      end
      threads.each { |t| t.join }
    end

    def show_identity
      self.signs.each_with_index { |s, i| s.show_text "#{i} #{s.path}" }
    end

    def length
      self.signs.length
    end
  end
end