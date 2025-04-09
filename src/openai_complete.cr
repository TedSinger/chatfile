require "./chat"
require "./persona"
require "openai"

module OpenAIComplete

    class OpenAIConversation
        def initialize(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
            @chat = chat
            @persona_config = persona_config
        end
    end
    DEFAULT_OPENAI_PARAMS = Persona::PersonaFragment.new(
        nil,
        nil,
        {
            "model" => "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
            "temperature" => "0.7",
            "anthropic_version" => "bedrock-2023-05-31",
            "max_tokens" => "4096",
            "stop_sequences" => "[]",
            "top_p" => "0.9",
            "top_k" => "250",
        }
    )

    def self.generic_role_to_openai_role(role : String) : OpenAI::ChatMessageRole
        case role
        when "user"
            OpenAI::ChatMessageRole::User
        when "ai"
            OpenAI::ChatMessageRole::Assistant
        else
            raise "Unknown role: #{role}"
        end
    end

    def self.delta_to_string(delta : OpenAI::ChatCompletionStreamChoiceDelta | Nil) : String
        if delta
            content = delta.content
            if content
                content
            else
                ""
            end
        else
            ""
        end
    end

    def self.openai_api_complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
        conversation = OpenAIConversation.new(chat, persona_config)

        output_ch = Channel(String).new
        openai_client = OpenAI::Client.new(
            api_key: ENV["OPENAI_API_KEY"]
        )

        completion = openai_client.chat_completion(
            OpenAI::ChatCompletionRequest.new(
                model: "gpt-4o-mini",
                messages: chat.conversation_blocks.map { |role, content|
                    OpenAI::ChatMessage.new(
                        role: generic_role_to_openai_role(role),
                        content: content
                    )
                },
            )
        )
        
        spawn do
            content = completion.choices[0].message.content
            if content
                output_ch.send(content)
            end
        end

        output_ch
        
    end
end