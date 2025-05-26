require "./persona_config"
require "json"

module Persona
  module Role
    USER                 = "user"
    META                 = "meta"
    AI                   = "ai"
    SHELL                = "$"
    JSON_RESPONSE_FORMAT = "{}"
  end

  struct Persona
    getter key_value_pairs : Hash(String, Tuple(String, String))
    getter role : Role?

    def initialize(@key_value_pairs : Hash(String, Tuple(String, String)), @role : Role? = nil)
    end

    def self.from_hash(source : String, hash : Hash(String, String))
      Persona.new(
        hash.reduce({} of String => Tuple(String, String)) { |acc, (key, value)| acc[key] = {source, value}; acc },
        nil
      )
    end

    def <<(other : Persona)
      Persona.new(
        @key_value_pairs.merge(other.key_value_pairs),
        @role || other.role
      )
    end

    def self.zero
      Persona.new(
        {} of String => Tuple(String, String),
        nil
      )
    end

    def to_s
      stuff = @key_value_pairs.map { |key, value| {key, value[0], value[1].size > 40 ? value[1][0..40] + "..." : value[1]} }
      stuff = stuff.sort_by { |key, source, value| {key, source} }
      stuff.map { |key, source, value| "#{key}: #{value} (from #{source})" }.join("\n")
    end

    def enrich_json(json : JSON::Builder, simple_params : Array(Tuple(String, String, String.class | Int32.class | Float64.class | JSON::Any.class)))
      simple_params.each do |json_key, persona_key, type|
        if @key_value_pairs[persona_key]?
          source, value = @key_value_pairs[persona_key]
          if value.strip == ""
            puts "Skipping empty value for #{persona_key} from #{source}"
          elsif type == String
            json.field(json_key, value)
          elsif type == Int32
            json.field(json_key, value.to_i)
          elsif type == Float64
            json.field(json_key, value.to_f)
          elsif type == JSON::Any
            json.field(json_key, JSON.parse(value))
          else
            raise NotImplementedError.new("Type #{type} not implemented")
          end
        end
      end
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

    def explicit_role
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

    def resolve(kind : String, config : PersonaConfig::PersonaConfig)
      persona = Persona.zero
      @keywords.each do |keyword|
        if config[keyword]?
          persona = persona << Persona.from_hash(keyword, config[keyword])
        end
      end
      persona = persona << Persona.from_hash(kind, @key_value_pairs)
      persona
    end
  end
end
