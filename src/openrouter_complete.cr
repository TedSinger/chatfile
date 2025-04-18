require "http/client"

module OpenRouterComplete
    def self.can_access() : Bool
        if ENV["OPENROUTER_API_KEY"]
            true
        else
            false
        end
    end

    class OpenRouterConversation
        def initialize(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
            @chat = chat
            @persona_config = persona_config
        end
    end

    DEFAULT_OPENROUTER_PARAMS = Persona::PersonaFragment.new(
        nil,
        nil,
        {
            "model" => "x-ai/grok-2-1212",
        }
    )

    def self.generic_role_to_openrouter_role(role : String) : String
        case role
        when "user"
            "user"
        when "ai"
            "assistant"
        else
            raise "Unknown role: #{role}"
        end
    end

    def self.openrouter_api_complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
        client = HTTP::Client.new(URI.new("https", "openrouter.ai"))
        conversation = OpenRouterConversation.new(chat, persona_config)
        persona = chat.last_block_persona(DEFAULT_OPENROUTER_PARAMS, persona_config)
        conversation_body = JSON.build do |json|
            json.object do
                json.field("model", persona.key_value_pairs["model"])
                json.field("messages", chat.conversation_blocks.map { |role, content|
                    {"role" => generic_role_to_openrouter_role(role), "content" => content}
                })
                json.field("stream", true)
            end
        end
        headers = HTTP::Headers.new()
        headers.add("Authorization", "Bearer #{ENV["OPENROUTER_API_KEY"]}")
        headers.add("Content-Type", "application/json")
        ch = Channel(String).new
        spawn do
            client.post("/api/v1/chat/completions", headers, conversation_body) do |response|
                response.body_io.each_line do |line|
                    next if line.empty? || line.starts_with?("data: [DONE]")
                    if line.starts_with?("data: ")
                        begin
                            json = JSON.parse(line[6..-1])
                            if delta = json.dig?("choices", 0, "delta", "content")
                                ch.send(delta.as_s)
                            end
                        rescue JSON::ParseException
                            puts "Error: #{line}"
                        end
                    else
                        puts "Unknown line: #{line}"
                    end
                end
            end
            ch.close
        end
        ch
    end
end