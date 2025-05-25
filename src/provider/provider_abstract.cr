module Provider
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona : Persona::Persona) : Iterator(String)

    abstract def initialize(env : Hash(String, String))
    abstract def defaults : Persona::Persona
  end

  class CompleterError < Exception
    def initialize(@status : HTTP::Status, @message : String)
    end
  end
end
