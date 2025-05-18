require "aws/bedrock"
require "aws/bedrock_events"
require "./completer"
require "../chat"
require "../persona"
require "./aws_creds"

module Completer::Bedrock
  class Completer < Completer
    def initialize(credentials : Hash(String, String | Nil))
      @credentials = credentials
    end

    def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
      persona = chat.last_block_persona("bedrock", persona_config)
      puts persona
      conversation_body = JSON.build do |json|
        json.object do
          json.field "inferenceConfig" do
            json.object do
              json.field "maxTokens", (persona.key_value_pairs["max_tokens"]).to_i
              json.field "stopSequences", JSON.parse(persona.key_value_pairs["stop_sequences"])
              json.field "temperature", (persona.key_value_pairs["temperature"]).to_f
              json.field "topP", (persona.key_value_pairs["top_p"]).to_f
            end
          end
          json.field "messages", chat.conversation.map { |role, content|
            {
              "role" => Bedrock.generic_role_to_bedrock_role(role),
              "content" => [{"type" => "text", "text" => content}]
            }
          }
          json.field "system", [{"type" => "text", "text" => persona.key_value_pairs["prompt"]}]
          json.field "toolConfig", {
            "toolChoice" => {
              "any" => {} of String => String
            },
            "tools" => [
              {
                "toolSpec" => Bedrock.generic_json_schema_to_bedrock_tool(chat.response_format.not_nil!)
              }
            ]
          } if chat.response_format
        end
      end

      client = AWS::BedrockRuntime::Client.new(
        @credentials["AWS_ACCESS_KEY_ID"]?.not_nil!,
        @credentials["AWS_SECRET_ACCESS_KEY"]?.not_nil!,
        @credentials["AWS_REGION"]?.not_nil!,
        sts_token: @credentials["AWS_SESSION_TOKEN"]?
      )
      response_iter = client.converse_stream(
        persona.key_value_pairs["model"],
        conversation_body
      )
      if response_iter.is_a?(Tuple(HTTP::Status, String))
        raise CompleterError.new(response_iter.first, response_iter.last)
      end
      response_iter.compact_map { |event| Bedrock.extract_event_from_bedrock_response(AWS::BedrockRuntime::ConverseStreamEvent.from_event_payload(event)) }
    end
  end


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

  def self.extract_event_from_bedrock_response(event : AWS::BedrockRuntime::ConverseStreamEvent) : String | Iterator::Stop | Nil
    case event
    when AWS::BedrockRuntime::ConverseStreamEvent::ContentBlockDelta
      event.delta.text || event.delta.toolUse.not_nil!.input
    else
      nil
    end
  end

  def self.generic_json_schema_to_bedrock_tool(json_schema : JSON::Any) : JSON::Any
    # {
    #   "type" => "function",
    #   "function" => {
    #     "name" => "get_current_time",
    #     "description" => "Get the current time",
    #     "inputSchema" => {"json": {
    #       "type": "object",
    #       "properties": {
    #           "sign": {
    #               "type": "string",
    #               "description": "The call sign for the radio station for which you want the most popular song. Example calls signs are WZPZ and WKRP."
    #           }
    #       },
    #       "required": [
    #           "sign"
    #       ]
    #   }}
    #   }
    # }
    if json_schema.dig?("type") == "object"
      JSON.parse(JSON.build do |json|
        json.object do
          json.field("type", "function")
          json.field("name", json_schema.dig?("name") || json_schema.dig?("title") || "unnamed")
          json.field("description", json_schema.dig?("description") || "unnamed")
          json.field("inputSchema", {
            "json" => json_schema
          })
        end
      end)
    else
      raise "Don't know how to convert JSON schema to Bedrock tool: #{json_schema}"
    end
  end
  
end
