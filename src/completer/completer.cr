module Completer
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
  end
end
