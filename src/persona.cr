require "./persona_config"

module Persona
  module Role
    USER                 = "user"
    META                 = "meta"
    AI                   = "ai"
    SHELL                = "$"
    JSON_RESPONSE_FORMAT = "{}"
  end

  struct Persona
    getter key_value_pairs : Hash(String, String)
    getter role : Role?

    def initialize(@key_value_pairs : Hash(String, String), @role : Role? = nil)
    end

    def <<(other : Persona)
      Persona.new(
        @key_value_pairs.merge(other.key_value_pairs),
        @role || other.role
      )
    end

    def <<(other : Hash(String, String))
      Persona.new(
        @key_value_pairs.merge(other),
        @role
      )
    end

    def self.zero
      Persona.new(
        {} of String => String,
        nil
      )
    end
  end

  struct PersonaLine
    getter keywords : Array(String)
    getter key_value_pairs : Hash(String, String)

    def initialize(@keywords : Array(String), @key_value_pairs : Hash(String, String))
    end

    def self.is_persona_line(line)
      line.starts_with?("#@")
    end

    def self.parse_persona_line(line)
      raise ArgumentError.new("Line must start with #@") unless line.starts_with?("#@")

      parts = line[2..-1].split(/\s+/)
      keywords = [] of String
      key_value_pairs = {} of String => String

      parts.each do |part|
        if part.includes?("=")
          key, value = part.split("=", 2)
          key_value_pairs[key.strip] = value.strip
        else
          keywords << part.strip if part.strip.size > 0
        end
      end
      PersonaLine.new(keywords, key_value_pairs)
    end

    def inferred_role
      if @keywords.includes?(Role::USER)
        Role::USER
      elsif @keywords.includes?(Role::JSON_RESPONSE_FORMAT)
        Role::JSON_RESPONSE_FORMAT
      elsif @keywords.includes?(Role::META)
        Role::META
      elsif @keywords.includes?(Role::SHELL)
        Role::SHELL
      elsif !@keywords.empty?
        Role::AI
      else
        nil
      end
    end

    def <<(other : PersonaLine)
      PersonaLine.new(
        @keywords + other.keywords,
        @key_value_pairs.merge(other.key_value_pairs)
      )
    end

    def self.zero
      PersonaLine.new([] of String, {} of String => String)
    end

    def resolve(config : PersonaConfig::PersonaConfig)
      persona = Persona.zero
      @keywords.each do |keyword|
        if config["shortcut:#{keyword}"]?
          persona = persona << config["shortcut:#{keyword}"]
        end
      end
      @key_value_pairs.each do |key, value|
        persona = persona << {key => value}
      end
      persona
    end
  end
end
