require "http/client"
require "./provider"
require "http/status"
require "../chat"
require "../persona"

module Provider::OpenAI
  def self.can_access(env : Hash(String, String)) : Bool
    env.has_key?("OPENAI_API_KEY")
  end

  class Completer < Completer
    def initialize(@env : Hash(String, String))
    end

    def complete(chat : Chat::Chat, persona_config : Persona::PersonaConfig) : Iterator(String)
      client = HTTP::Client.new(URI.new("https", "api.openai.com"))
      persona = chat.last_block_persona("openai", persona_config)
      puts persona
      conversation_body = JSON.build do |json|
        json.object do
          json.field("model", persona.key_value_pairs["model"])
          json.field("messages",
            [
              {"role" => "system", "content" => persona.key_value_pairs["prompt"]},
              *chat.conversation.map { |role, content|
                {"role" => OpenAI.generic_role_to_openai_role(role), "content" => content}
              },
            ]
          )
          json.field("stream", true)
          json.field("temperature", persona.key_value_pairs["temperature"].to_f)
          json.field("max_tokens", persona.key_value_pairs["max_tokens"].to_i)
          json.field("top_p", persona.key_value_pairs["top_p"].to_f)
          json.field("frequency_penalty", persona.key_value_pairs["frequency_penalty"].to_f)
          json.field("presence_penalty", persona.key_value_pairs["presence_penalty"].to_f)
          json.field("response_format", OpenAI.generic_json_schema_to_openai_response_format(chat.response_format.not_nil!)) if chat.response_format
        end
      end

      headers = HTTP::Headers.new
      headers.add("Authorization", "Bearer #{@env["OPENAI_API_KEY"]}")
      headers.add("Content-Type", "application/json")

      client.post("/v1/chat/completions", headers, conversation_body) do |response|
        if response.status_code == 200
          return EventStream.new(response.body_io)
        else
          raise CompleterError.new(HTTP::Status.new(response.status_code), response.body_io.gets_to_end)
        end
      end
    end
  end

  def self.generic_role_to_openai_role(role : String) : String
    case role
    when "user"
      "user"
    when "ai"
      "assistant"
    else
      raise "Unknown role: #{role}"
    end
  end

  def self.generic_json_schema_to_openai_response_format(json_schema : JSON::Any) : JSON::Any
    if json_schema.dig?("type") == "json_schema"
      json_schema
    elsif json_schema.dig?("type") == "object"
      JSON.parse(JSON.build do |json|
        json.object do
          json.field("type", "json_schema")
          json.field("json_schema", {"name" => "unnamed", "schema" => json_schema})
        end
      end)
    else
      raise "Don't know how to convert JSON schema to OpenRouter response format: #{json_schema}"
    end
  end

  class EventStream
    include Iterator(String)

    def initialize(@io : IO)
    end

    def maybe_next
      if @io.closed?
        return stop
      end
      line = @io.gets
      if line.nil? || line.empty?
        return nil
      end
      if line.starts_with?("data: [DONE]")
        return stop
      end
      if line.starts_with?("data: ")
        begin
          json = JSON.parse(line[6..-1])
          if delta = json.dig?("choices", 0, "delta", "content")
            return delta.as_s
          elsif json.dig?("error")
            if raw = json.dig?("error", "metadata", "raw")
              raise raw.as_s
            else
              raise "Error: #{json["error"]}"
            end
          end
        rescue JSON::ParseException
          raise "Error: #{line}"
        end
      else
        raise "Unknown line: #{line}"
      end
    end

    def next
      while (chunk = maybe_next).nil?
      end
      chunk
    end
  end
end
