require "aws/bedrock"
require "./chat"
require "./persona"

module BedrockComplete

    def self.can_access() : Bool
        if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
            true
        else
            false
        end
    end

    class BedrockConversation
        def initialize(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
            @chat = chat
            @persona_config = persona_config
        end
    end
    DEFAULT_BEDROCK_PARAMS = Persona::PersonaFragment.new(
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

    def self.generic_role_to_bedrock_role(role : String) : String
        case role
        when "user"
            "user"
        when "ai"
            "assistant"
        else
            raise "Unknown role: #{role}"
        end
    end

    def self.extract_event_from_bedrock_response(event : JSON::Any) : String|Iterator::Stop|Nil
        case event["type"]
        when "content_block_delta"
            event["delta"]["text"].as_s
        when "content_block_stop"
            Iterator::Stop.new
        when "error"
            raise "Error: #{event["error"]}"
        when "content_block_start"
            puts event
        when "message_start"
            puts event
        when "message_delta"
            Iterator::Stop.new
        when "message_stop"
            Iterator::Stop.new
        else
            raise "Unknown event type: #{event["type"]}"
        end
    end
    
    def self.bedrock_api_complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
        persona = chat.last_block_persona(DEFAULT_BEDROCK_PARAMS, persona_config)
        bedrock_conversation = BedrockConversation.new(chat, persona_config)
        puts chat.conversation_blocks
        conversation_body = JSON.build do |json|
            json.object do
                json.field("messages", chat.conversation_blocks.map { |role, content|
                    {
                        "role" => generic_role_to_bedrock_role(role),
                        "content" => [{"type" => "text", "text" => content}]
                    }
                })
                json.field("max_tokens", (persona.key_value_pairs["max_tokens"]).to_i)
                json.field("temperature", (persona.key_value_pairs["temperature"]).to_f)
                json.field("anthropic_version", persona.key_value_pairs["anthropic_version"])
                json.field("top_p", (persona.key_value_pairs["top_p"]).to_f)
                json.field("top_k", (persona.key_value_pairs["top_k"]).to_i)
                json.field("stop_sequences", JSON.parse(persona.key_value_pairs["stop_sequences"]))
                json.field("system", persona.prompt)
            end
        end

        client = AWS::BedrockRuntime::Client.new
        response_iter = client.invoke_model_with_response_stream(
            persona.key_value_pairs["model"],
            conversation_body
        )
        response_iter.compact_map { |event| extract_event_from_bedrock_response(event) }
    end                

end
