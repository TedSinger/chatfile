require "./chat"
require "./persona"
require "./bedrock_api"

module Bedrock

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

    def self.bedrock_api_complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig)
        # cfg = AWS::Config.new
        persona = chat.last_block_persona(DEFAULT_BEDROCK_PARAMS, persona_config)
        bedrock_conversation = BedrockConversation.new(chat, persona_config)
        conversation_body = JSON.build do |json|
            json.object do
                json.field("messages", chat.blocks.map { |block|
                    {
                        "role" => block.persona_line.keywords.includes?("user") ? "user" : "assistant",
                        "content" => [{"type" => "text", "text" => block.content.strip}]
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
        puts conversation_body

        client = AWS::BedrockRuntime::Client.new
        response_ch = client.invoke_model_with_response_stream(
            persona.key_value_pairs["model"],
            conversation_body,
            "application/json",
            "application/json",
            nil,
            nil,
            nil,
            nil
        )
        output_ch = Channel(String).new
        spawn do
            while event = response_ch.receive?
                # puts event

                case event["type"]
                when "content_block_delta"
                    output_ch.send(event["delta"]["text"].as_s)
                when "content_block_stop"
                    break
                when "error"
                    raise "Error: #{event["error"]}"
                when "content_block_start"
                    # puts event
                when "message_start"
                    # puts event
                when "message_delta"
                    break
                when "message_stop"
                    break
                else
                    raise "Unknown event type: #{event["type"]}"
                end
            end
            output_ch.close
        end
        output_ch
    end                

end
