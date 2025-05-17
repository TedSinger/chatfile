module Completer
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
  end

  class CompleterError < Exception
    def initialize(@status : HTTP::Status, @message : String)
    end
  end
end
