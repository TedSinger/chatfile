require "../persona_config"
require "./anthropic"
require "./bedrock"
require "./openai"
require "./openrouter"
require "./provider_abstract"

module Provider
  KNOWN_PROVIDERS = {
    "bedrock"    => {Bedrock, Bedrock::Completer},
    "openrouter" => {OpenRouter, OpenRouter::Completer},
    "openai"     => {OpenAI, OpenAI::Completer},
    "anthropic"  => {Anthropic, Anthropic::Completer},
  }

  def self.get_completer(provider_name : String?, env : Hash(String, String)) : Provider::Completer
    if provider_name
      provider = KNOWN_PROVIDERS[provider_name].not_nil!
      if provider[0].can_access(env)
        return provider[1].new(env)
      else
        raise "No access to #{provider_name}"
      end
    else
      KNOWN_PROVIDERS.each do |provider_name, provider|
        if provider[0].can_access(env)
          puts "Using #{provider_name} because none was specified"
          return provider[1].new(env)
        end
      end
      raise "No provider found"
    end
  end
end
