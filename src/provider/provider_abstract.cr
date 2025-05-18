module Provider
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona_config : PersonaConfig::PersonaConfig) : Iterator(String)

    abstract def initialize(env : Hash(String, String))
  end

  class CompleterError < Exception
    def initialize(@status : HTTP::Status, @message : String)
    end
  end
end
