require "http/client"
require "./provider_abstract"
require "http/status"
require "../chat"
require "../persona_config"

module Provider::OpenRouter
  def self.can_access(env : Hash(String, String)) : Bool
    env.has_key?("OPENROUTER_API_KEY")
  end

  SIMPLE_PARAMS = [
    {"model", "model", String},
    {"max_tokens", "max_tokens", Int32},
    {"temperature", "temperature", Float64},
    {"top_p", "top_p", Float64},
    {"top_k", "top_k", Int32},
    {"frequency_penalty", "frequency_penalty", Float64},
    {"presence_penalty", "presence_penalty", Float64},
    {"min_p", "min_p", Float64},
    {"repetition_penalty", "repetition_penalty", Float64},
  ]

  class Completer < Completer
    def initialize(@env : Hash(String, String))
    end

    def defaults : Persona::Persona
      Persona::Persona.from_hash("openrouter default", {"model" => "x-ai/grok-3-mini-beta"})
    end

    def complete(chat : Chat::Chat, persona : Persona::Persona) : Iterator(String)
      persona = defaults << persona
      puts "Using persona:"
      puts persona.to_s
      client = HTTP::Client.new(URI.new("https", "openrouter.ai"))
      conversation_body = JSON.build do |json|
        json.object do
          json.field("messages",
            [
              {"role" => "system", "content" => persona.key_value_pairs["prompt"][1]},
              *chat.conversation.map { |role, content|
                {"role" => OpenRouter.generic_role_to_openrouter_role(role), "content" => content}
              },
            ]
          )
          json.field("stream", true)
          persona.enrich_json(json, SIMPLE_PARAMS)
          json.field("response_format", OpenRouter.generic_json_schema_to_openrouter_response_format(chat.response_format.not_nil!)) if chat.response_format
        end
      end

      headers = HTTP::Headers.new
      headers.add("Authorization", "Bearer #{@env["OPENROUTER_API_KEY"]}")
      headers.add("Content-Type", "application/json")

      client.post("/api/v1/chat/completions", headers, conversation_body) do |response|
        if response.status_code == 200
          return EventStream.new(response.body_io)
        else
          raise CompleterError.new(HTTP::Status.new(response.status_code), response.body_io.gets_to_end)
        end
      end
    end
  end

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

  def self.generic_json_schema_to_openrouter_response_format(json_schema : JSON::Any) : JSON::Any
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
      elsif line.includes?("OPENROUTER PROCESSING")
        nil
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
