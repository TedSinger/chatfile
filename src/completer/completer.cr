module Completer
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
  end

  class CompleterError < Exception
    def initialize(@status : HTTP::Status, @message : String)
    end
  end


  def self.get_completer(use_bedrock : Bool, use_openrouter : Bool, use_openai : Bool, env : Hash(String, String)) : Completer
    # first check for an explicit flag
    if use_bedrock
      puts "Using Bedrock because of --bedrock flag"
      return Bedrock::Completer.new(AwsCreds.get_credentials)
    elsif use_openrouter
      puts "Using OpenRouter because of --openrouter flag"
      return OpenRouter::Completer.new(env)
    elsif use_openai
      puts "Using OpenAI because of --openai flag"
      return OpenAI::Completer.new(env)
    # otherwise check .can_access
    elsif OpenRouter.can_access
      puts "Using OpenRouter because of .can_access"
      return OpenRouter::Completer.new(env)
    elsif AwsCreds.can_access
      puts "Using Bedrock because of .can_access"
      return Bedrock::Completer.new(AwsCreds.get_credentials)
    elsif OpenAI.can_access
      puts "Using OpenAI because of .can_access"
      return OpenAI::Completer.new(env)
    else
      raise "No access to OpenRouter, Bedrock, or OpenAI"
    end
  end
end
