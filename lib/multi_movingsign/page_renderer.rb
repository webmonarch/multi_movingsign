module MultiMovingsign
  # Renders a page definition (Hash/YAML) into something that is easily displayable by the MovingsignApi (page solution)
  class PageRenderer
    DEFAULT_CHARACTER_WIDTH = 5

    # @param page [Hash] page definition as a Hash
    # @param options [Hash] options for the rendering operation
    # @option options [Integer] :count the number of signs to render to (default: 1)
    #
    # @return [Hash] a page solution hash
    def render(page, options = {})
      # Vocabulary - Terms used here
      #
      # Sign
      #     A single LED sign, stacked vertically with other LED signs...together forming a screen
      # Screen
      #     N LED signs stacked vertically.  Together they can display a screen of information at a time
      # Page Definition
      #     A page of information to be broken up and displayed on available signs, consisting of a title and n Line Definitions.
      # Line Definition
      #     A line of information from the page definition.  NOTE: a single line might turn into multiple screens of information
      # Line Segment
      #     A piece of a line definition, displayed on it's own sign, seprate from previous line segments of the same line.
      #

      signs_available = (options[:count] || 1)
      page_title = page['title']
      line_definitions = page['lines']
      pin_title = signs_available > 1

      page_definition = PageDefinition.from_hash page
      page_segments = page_definition.calculate_segments(signs_available)
      screens = page_segments.map { |s| s.calculate_screens(signs_available, screen_width) }.flatten

      ## Preview Solution
      #screens.each do |screen|
      #  puts "----"
      #  (0..(signs_available-1)).each do |i|
      #    puts screen.line(i)
      #  end
      #end
      #puts "----"

      signs = (0..(signs_available-1)).map { |sign_index| {'content' => screens.map { |s| s.line(sign_index) }.join("\n")} }

      {'signs' => signs, 'lines' => screens.length}
    end

    private

    def screen_width
      80
    end

    def self.calculate_width(string)
      string.length * DEFAULT_CHARACTER_WIDTH
    end
  end

  class PageDefinition
    attr_accessor :title
    attr_accessor :line_definitions

    def self.from_hash(hash)
      obj = self.new

      obj.title = hash['title'] || ''
      obj.line_definitions = hash['lines'].map { |ld| LineDefinition.from_hash ld }

      obj
    end

    # Splits a {PageDefinition} into an array of {PageSegment}s
    #
    # @param signs [Integer] the number of signs (lines) available to render to
    # @param options [Hash]
    # @option options [Boolean] +:pin_title+
    def calculate_segments(signs, options = {})
      pin_title = signs > 1 && (options[:pin_title] != false)
      page_segments = []
      line_definitions = self.line_definitions.clone.reverse

      index = 0
      while !line_definitions.empty?
        include_title = pin_title || index == 0             # include the title in this line segment?
        line_count = include_title ? signs - 1 : signs      # number of line definitions to include in this page segment (less the title if included)

        page_segments << PageSegment.new(include_title ? self.title : nil, line_definitions.pop(line_count).reverse)

        index += 1
      end

      page_segments
    end
  end

  class LineDefinition
    attr_accessor :prefix
    attr_accessor :line_segments

    def self.from_hash(hash)
      obj = self.new

      obj.prefix = hash['prefix'] || nil
      obj.line_segments = (hash['segments'] || hash['content'] || []).map { |segment| LineSegment.new(obj.prefix, segment) }

      obj
    end

    def prefix?
      !!self.prefix
    end
  end

  class LineSegment
    attr_accessor :prefix
    attr_accessor :segment

    def initialize(prefix, segment)
      self.prefix = prefix
      self.segment = segment
    end

    def prefix?
      !!self.prefix
    end

    # If necessary, splits this LineSegment into multiple appropriate for displaying at once on the screen
    def split_if_necessary(max_width)
      raise InvalidInputError, "Prefix '' is too wide!" if (prefix? && PageRenderer.calculate_width(prefix) > max_width)

      if PageRenderer.calculate_width(self.to_s) <= max_width
        # segment isn't too long with prefix, return it as is
        [self]
      else
        # segment is too long, split it up into word segments finding the largest with the prefix appended that fits
        segments = []  # calculated segments
        prefix_width = prefix? ? PageRenderer.calculate_width(prefix) : 0

        words = segment.split(/ /)
        while !words.empty?
          index = words.length
          while index > 0 && PageRenderer.calculate_width(candidate = (candidate_words = words[0, index]).join(' ')) + prefix_width > max_width
            index -= 1
          end

          segments << self.class.new(prefix, candidate)
          words = words.drop index
        end

        segments
      end
    end

    def to_s
      prefix? ? prefix + segment : segment
    end

    def inspect
      to_s.inspect
    end
  end

  class PageSegment
    attr_accessor :title
    attr_accessor :line_definitions

    def initialize(title, line_definitions)
      self.title = title
      self.line_definitions = line_definitions
    end

    def title?
      !!self.title
    end

    def line_definitions?
      !self.line_definitions.empty?
    end

    # Turns a single page segment into n rendered screens of information
    def calculate_screens(number_of_signs, sign_width)
      raise "Title too long!" if title? && PageRenderer.calculate_width(title) >  sign_width

      if title? && !line_definitions?
        return Screen.new [title]
      end

      screens = []

      #puts line_definitions.map { |d| d.line_segments.map { |s| s.split_if_necessary(sign_width).map { |s| s.to_s} } }.inspect

      num_of_line_segments = line_definitions.map { |d| d.line_segments.length }.max
      (0..(num_of_line_segments - 1)).each do |segment_index|
        subsegments = line_definitions.map { |d| (s = d.line_segments[segment_index]) ? s.split_if_necessary(sign_width) : [] }
        num_of_subsegments = subsegments.map { |s| s.length }.max

        (0..(num_of_subsegments-1)).each do |subsegment_index|
          lines = []

          lines << title if title?
          lines.concat subsegments.map { |s| s[subsegment_index % s.length] || "" }

          screens << Screen.new(lines)
        end
      end

      screens
    end
  end

  class Screen
    attr_accessor :lines

    def initialize(lines)
      self.lines = lines
    end

    def line(index)
      self.lines[index] || " "
    end
  end
end