module Provider
  abstract class Completer
    abstract def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
  end

  class CompleterError < Exception
    def initialize(@status : HTTP::Status, @message : String)
    end
  end

  # Also serves as a default preference list
  KNOWN_PROVIDERS = ["bedrock", "openrouter", "openai"]


  def self.get_completer(provider_name_from_flag : String?, env : Hash(String, String)) : Completer
    if provider_name_from_flag
      requested_provider_name = provider_name_from_flag
      reason = "flag"
    elsif env["CHATFILE_PROVIDER"]?
      requested_provider_name = env["CHATFILE_PROVIDER"]
      reason = "env var"
    else
      requested_provider_name = nil
    end
    if requested_provider_name == "bedrock"
      puts "Using Bedrock because of #{reason}"
      return Bedrock::Completer.new(AwsCreds.get_credentials)
    elsif requested_provider_name == "openrouter"
      puts "Using OpenRouter because of #{reason}"
      return OpenRouter::Completer.new(env)
    elsif requested_provider_name == "openai"
      puts "Using OpenAI because of #{reason}"
      return OpenAI::Completer.new(env)
    else
      # otherwise check .can_access
      if OpenRouter.can_access
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
end
