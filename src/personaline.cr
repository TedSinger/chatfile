module PersonaLine
  struct PersonaLine
    getter keywords : Array(String)
    getter key_value_pairs : Hash(String, String)
    
    def initialize(keywords : Array(String), key_value_pairs : Hash(String, String))
      @keywords = keywords
      @key_value_pairs = key_value_pairs
    end
  end
    

  def self.is_persona_line(line)
    line.starts_with?("#%")
  end

  def self.parse_persona_line(line)
    raise ArgumentError.new("Line must start with #%") unless line.starts_with?("#%")

    parts = line[2..-1].strip.split(/\s+/)
    keywords = [] of String
    key_value_pairs = {} of String => String

    parts.each do |part|
      if part.includes?("=")
        key, value = part.split("=", 2)
        key_value_pairs[key] = value
      else
        keywords << part
      end
    end

    PersonaLine.new(keywords, key_value_pairs)
  end
end