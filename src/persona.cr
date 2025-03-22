module Persona
  struct Persona
    getter name : String
    getter prompt : String
    getter key_value_pairs : Hash(String, String)
    
  def initialize(name : String, prompt : String, key_value_pairs : Hash(String, String))
      @name = name
      @prompt = prompt
      @key_value_pairs = key_value_pairs
    end
  end
end

