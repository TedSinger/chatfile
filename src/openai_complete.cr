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
            "model" => "gpt-4o-mini",
            "temperature" => "0.7",
            "max_tokens" => "4096",
            "top_p" => "0.9",
            "presence_penalty" => "0.0",
            "frequency_penalty" => "0.0",
            "logit_bias" => "{}",
            "stop" => "[]",
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

        openai_client = OpenAI::Client.new(
            api_key: ENV["OPENAI_API_KEY"]
        )
        persona = chat.last_block_persona(DEFAULT_OPENAI_PARAMS, persona_config)
        system_message = OpenAI::ChatMessage.new(
            role: OpenAI::ChatMessageRole::System,
            content: persona.prompt
        )
        logit_bias = JSON.parse(persona.key_value_pairs["logit_bias"]).as_h.transform_values(&.as_f)
        stop = JSON.parse(persona.key_value_pairs["stop"]).as_a.map { |v| v.as_s }
        completion = openai_client.chat_completion(
            OpenAI::ChatCompletionRequest.new(
                model: persona.key_value_pairs["model"],
                messages: [system_message] + chat.conversation_blocks.map { |role, content|
                    OpenAI::ChatMessage.new(
                        role: generic_role_to_openai_role(role),
                        content: content
                    )
                },
                temperature: persona.key_value_pairs["temperature"].to_f,
                max_tokens: persona.key_value_pairs["max_tokens"].to_i,
                top_p: persona.key_value_pairs["top_p"].to_f,
                logit_bias: logit_bias,
                stop: stop,
                presence_penalty: persona.key_value_pairs["presence_penalty"].to_f,
                frequency_penalty: persona.key_value_pairs["frequency_penalty"].to_f,
                stream: false,
            )
        )
        
        output_ch = Channel(String).new
        spawn do
            content = completion.choices[0].message.content
            if content
                output_ch.send(content)
            end
            output_ch.close
        end

        output_ch
        
    end
end