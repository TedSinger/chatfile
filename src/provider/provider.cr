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

  def self.get_any_available(env : Hash(String, String)) : String
    KNOWN_PROVIDERS.each do |provider_name, provider|
      if provider[0].can_access(env)
        return provider_name
      end
    end
    raise "No provider found. Try setting OPENROUTER_API_KEY, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, OPENAI_API_KEY, or ANTHROPIC_API_KEY"
  end
end
