require "json"

module Persona
  module Role
    USER = "user"
    META = "meta"
    AI   = "ai"
    SHELL = "$"
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

    def resolve(config : PersonaConfig)
      persona = Persona.zero
      @keywords.each do |keyword|
        if config.shortcuts[keyword]?
          persona = persona << config.shortcuts[keyword]
        end
      end
      @key_value_pairs.each do |key, value|
        persona = persona << {key => value}
      end
      persona
    end
  end

  struct PersonaConfig
    include JSON::Serializable
    getter shortcuts : Hash(String, Hash(String, String))
    getter defaults_by_provider : Hash(String, Hash(String, String))

    def initialize(config : Hash(String, Hash(String, Hash(String, String))))
      @shortcuts = config["shortcuts"]
      @defaults_by_provider = config["defaults_by_provider"]
    end

    def <<(other : Persona)
      current = other
      @config.each do |key_to_match, regex_to_match_value, persona|
        if current.key_value_pairs[key_to_match]? && current.key_value_pairs[key_to_match].to_s.match(Regex.new(regex_to_match_value))
          current = persona.<<(current)
        end
      end
      current
    end

    def <<(other : PersonaConfig)
      PersonaConfig.new({
        "shortcuts"            => @shortcuts.merge(other.shortcuts) { |_, v1, v2| v1.merge(v2) },
        "defaults_by_provider" => @defaults_by_provider.merge(other.defaults_by_provider) { |_, v1, v2| v1.merge(v2) },
      })
    end

    def self.default_path
      File.expand_path("~/.config/chatfile/personas.json", home: Path.home)
    end

    def self.default_config
      default = self.from_json(<<-JSON
        {
            "defaults_by_provider": {
                "openrouter": {
                    "model": "x-ai/grok-3-mini-beta",
                    "prompt": "You are a helpful assistant that can answer questions and help with tasks.",
                    "temperature": "1.0",
                    "max_tokens": "4096",
                    "top_p": "1",
                    "top_k": "0",
                    "frequency_penalty": "0.0",
                    "presence_penalty": "0.0",
                    "min_p": "0.0",
                    "repetition_penalty": "1.0",
                    "top_a": "0.0",
                    "stop": "[]"
                },
                "bedrock": {
                    "model": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
                    "prompt": "You are a helpful assistant that can answer questions and help with tasks.",
                    "temperature": "0.7",
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": "4096",
                    "stop_sequences": "[]",
                    "top_p": "0.9",
                    "top_k": "250"
                }
            },
            "shortcuts": {}
        }
      JSON
      )
      if File.exists?(self.default_path)
        begin
          default << self.from_json(File.read(self.default_path))
        rescue e
          puts "Error parsing default config: #{e}"
          default
        end
      else
        default
      end
    end
  end
end
