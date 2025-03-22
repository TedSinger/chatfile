require "./chat"
require "./persona"
require "aws"

module Bedrock
    class BedrockConversation
        def initialize(chat : Chat, persona_config : PersonaConfig)
            @chat = chat
            @persona_config = persona_config
        end
    end
    DEFAULT_BEDROCK_PARAMS = {
        "model" => "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
        "temperature" => "0.7",
        "anthropic_version" => "bedrock-2023-05-31",
        "max_tokens" => "4096",
        "stop_sequences" => "[]",
        "top_p" => "0.9",
        "top_k" => "250",
    }

    def self.bedrock_api_complete(chat : Chat, persona_config : PersonaConfig, ch : Channel(String))
        cfg = Aws::Config::Builder.new.build
        client = Aws::BedrockRuntime::Client.new(cfg)
        bedrock_conversation = BedrockConversation.new(chat, persona_config)
        conversation_body = JSON.build do |json|
            json.object do
                json.field("messages", chat.blocks.map do |block|
                {
                    "role" => block.persona_line.keywords.includes?("user") ? "user" : "assistant",
                    "content" => [{"type" => "text", "text" => block.content.strip}]
                }
                json.field("max_tokens", (persona_config["max_tokens"] || DEFAULT_BEDROCK_PARAMS["max_tokens"]).to_i)
                json.field("temperature", (persona_config["temperature"] || DEFAULT_BEDROCK_PARAMS["temperature"]).to_f)
                json.field("anthropic_version", persona_config["anthropic_version"] || DEFAULT_BEDROCK_PARAMS["anthropic_version"])
                json.field("top_p", (persona_config["top_p"] || DEFAULT_BEDROCK_PARAMS["top_p"]).to_f)
                json.field("top_k", (persona_config["top_k"] || DEFAULT_BEDROCK_PARAMS["top_k"]).to_i)
                json.field("stop_sequences", JSON.parse(persona_config["stop_sequences"] || DEFAULT_BEDROCK_PARAMS["stop_sequences"]))
                # json.field("system", persona_config.prompt || DEFAULT_BEDROCK_PARAMS["prompt"]) # FIXME
                end)
            end
        end
        response = client.invoke_model_with_response_stream(conversation_body)
        response.stream.each do |event|
            case event
            when Aws::BedrockRuntime::Types::ResponseStreamMemberChunk
                ch.send(event.chunk.delta.text)
            end
        end
        ch.close
    end                

end
