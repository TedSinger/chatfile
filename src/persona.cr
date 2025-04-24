require "json"
module Persona
  struct PersonaFragment
    getter name : String | Nil
    getter prompt : String | Nil
    getter key_value_pairs : Hash(String, String)
    
    def initialize(name : String | Nil, prompt : String | Nil, key_value_pairs : Hash(String, String))
      @name = name
      @prompt = prompt
      @key_value_pairs = key_value_pairs
    end

    def merge_on_top_of(other : PersonaFragment | Persona)
      PersonaFragment.new(
        @name || other.name,
        @prompt || other.prompt,
        @key_value_pairs.merge(other.key_value_pairs)
      )
    end
  
    def self.zero_persona
      PersonaFragment.new(
        nil,
        nil,
        {} of String => String
      )
    end
  end

  struct Persona
    getter name : String
    getter prompt : String
    getter key_value_pairs : Hash(String, String)
    
    def initialize(name : String, prompt : String, key_value_pairs : Hash(String, String))
      @name = name
      @prompt = prompt
      @key_value_pairs = key_value_pairs
    end

    def merge_on_top_of(other : PersonaFragment | Persona)
      Persona.new(
        @name,
        @prompt,
        @key_value_pairs.merge(other.key_value_pairs)
      )
    end
  end
  struct PersonaConfig
    getter config : Hash(String, Persona)

    def initialize(config : Hash(String, Persona))
      @config = config
    end

    def [](name : String) : Persona | Nil
      @config[name]? || @config.values.find { |persona| persona.name.split('_').join.upcase == name.upcase }
    end

    def merge_on_top_of(other : PersonaConfig)
      PersonaConfig.new(@config.merge(other.config))
    end
  end

  def self.parse_persona_config(config_json : String)
    config = Hash(String, Hash(String, String)).from_json(config_json)
    personas = {} of String => Persona
    config.each do |name, config|
      key_value_pairs = {} of String => String
      config.each do |key, value|
        key_value_pairs[key] = value
      end
      personas[name] = Persona.new(name, config["prompt"], key_value_pairs)
    end
    PersonaConfig.new(personas)
  end

  def self.default_path
    File.expand_path("~/.config/chatfile/personas.json", home:Path.home)
  end

  def self.default_config
    default = self.parse_persona_config(<<-JSON
      {"default":{"prompt":"You are a helpful, but laconic, succinct, and terse assistant.", "max_tokens":"100","temperature":"0.5"}}
    JSON
    )
    if File.exists?(self.default_path)
      from_cfg = self.parse_persona_config(File.read(self.default_path))
      from_cfg.merge_on_top_of(default)
    else
      default
    end
  end

  struct PersonaLine
    getter keywords : Array(String)
    getter key_value_pairs : Hash(String, String)
    
    def initialize(keywords : Array(String), key_value_pairs : Hash(String, String))
      @keywords = keywords
      @key_value_pairs = key_value_pairs
    end

    def to_persona_and_fragment(persona_config : PersonaConfig)
      persona = PersonaFragment.zero_persona
      @keywords.each do |keyword|
        named_persona = persona_config[keyword]
        if named_persona
          persona = persona.merge_on_top_of(named_persona)
        end
      end

      fragment = PersonaFragment.new(
        nil,
        nil,
        @key_value_pairs
      )
      {persona, fragment}
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