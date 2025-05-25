require "http/status"
require "../chat"
require "../persona_config"
require "./provider_abstract"
require "json"

module Provider::Anthropic
  def self.can_access(env : Hash(String, String)) : Bool
    env.has_key?("ANTHROPIC_API_KEY")
  end

  SIMPLE_PARAMS = [
    {"model", "model", String},
    {"max_tokens", "max_tokens", Int32},
    {"system", "prompt", String},
    {"temperature", "temperature", Float64},
    {"stop_sequences", "stop_sequences", JSON::Any},
    {"top_k", "top_k", Int32},
    {"top_p", "top_p", Float64},
  ]

  class Completer < Completer
    def initialize(@env : Hash(String, String))
    end

    def defaults : Persona::Persona
      Persona::Persona.from_hash("anthropic default", {"model" => "claude-3-7-sonnet-20250219"})
    end

    def complete(chat : Chat::Chat, persona : Persona::Persona) : Iterator(String)
      persona = defaults << persona
      puts "Using persona:"
      puts persona.to_s
      client = HTTP::Client.new(URI.new("https", "api.anthropic.com"))
      headers = HTTP::Headers.new
      headers.add("x-api-key", @env["ANTHROPIC_API_KEY"])
      headers.add("anthropic-version", "2023-06-01")
      headers.add("content-type", "application/json")
      thinking = persona.key_value_pairs["thinking.type"]? == "enabled" ? {
        "budget_tokens" => persona.key_value_pairs["thinking.budget_tokens"][1].to_i,
        "type"          => "enabled",
      } : {"type" => "disabled"}
      conversation_body = JSON.build do |json|
        json.object do
          persona.enrich_json(json, SIMPLE_PARAMS)
          json.field("messages",
            chat.conversation.map { |role, content|
              {"role" => Anthropic.generic_role_to_anthropic_role(role), "content" => content}
            }
          )
          json.field("stream", true)
          if chat.response_format
            json.field "tool_choice" do
              json.object do
                json.field "type", "tool"
                json.field "name", "json_schema"
              end
            end
            json.field("tools", [
              Anthropic.generic_json_schema_to_anthropic_response_format(chat.response_format.not_nil!),
            ])
          end
          json.field("thinking", thinking) if chat.response_format.nil?
        end
      end

      client.post("/v1/messages", headers, conversation_body) do |response|
        if response.status_code == 200
          return EventStream.new(response.body_io)
        else
          raise CompleterError.new(HTTP::Status.new(response.status_code), response.body_io.gets_to_end)
        end
      end
    end
  end

  def self.generic_role_to_anthropic_role(role : String) : String
    case role
    when "user"
      "user"
    when "ai"
      "assistant"
    else
      raise "Unknown role: #{role}"
    end
  end

  def self.generic_json_schema_to_anthropic_response_format(json_schema : JSON::Any) : JSON::Any
    # [
    #   {
    #     "name": "get_stock_price",
    #     "description": "Get the current stock price for a given ticker symbol.",
    #     "input_schema": {
    #       "type": "object",
    #       "properties": {
    #         "ticker": {
    #           "type": "string",
    #           "description": "The stock ticker symbol, e.g. AAPL for Apple Inc."
    #         }
    #       },
    #       "required": ["ticker"]
    #     }
    #   }
    # ]
    if json_schema.dig?("type") == "object"
      JSON.parse(JSON.build do |json|
        json.object do
          json.field("name", "json_schema")
          json.field("description", "")
          json.field("input_schema", json_schema)
        end
      end)
    elsif json_schema.dig?("input_schema", "type") == "object"
      return json_schema
    else
      raise "Don't know how to convert JSON schema to Anthropic response format: #{json_schema}"
    end
  end

  class EventStream
    include Iterator(String)

    # https://docs.anthropic.com/en/docs/build-with-claude/streaming
    # event: message_start
    # data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-7-sonnet-20250219", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

    # event: content_block_start
    # data: {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}

    # event: ping
    # data: {"type": "ping"}

    # event: content_block_delta
    # data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

    # event: content_block_delta
    # data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "!"}}

    # event: content_block_stop
    # data: {"type": "content_block_stop", "index": 0}

    # event: message_delta
    # data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null}, "usage": {"output_tokens": 15}}

    # event: message_stop
    # data: {"type": "message_stop"}

    # event: content_block_start
    # data: {"type": "content_block_start", "index": 0, "content_block": {"type": "thinking", "thinking": ""}}

    # event: content_block_delta
    # data: {"type": "content_block_delta", "index": 0, "delta": {"type": "thinking_delta", "thinking": "Let me solve this step by step:\n\n1. First break down 27 * 453"}}

    # event: content_block_delta
    # data: {"type": "content_block_delta", "index": 0, "delta": {"type": "thinking_delta", "thinking": "\n2. 453 = 400 + 50 + 3"}}

    def initialize(@io : IO)
      @thinking = false
    end

    def maybe_next
      if @io.closed?
        return stop
      end
      line = @io.gets
      if line.nil? || line.empty?
        return nil
      end
      if line.starts_with?("data: ")
        json = JSON.parse(line[6..-1])
        if json.dig?("type") == "content_block_start"
          if json.dig?("content_block", "type") == "thinking"
            @thinking = true
            return "<thinking>"
          elsif @thinking
            @thinking = false
            return "</thinking>\n"
          else
            return nil
          end
        elsif json.dig?("type") == "message_stop"
          return stop
        elsif delta = json.dig?("delta", "text")
          return delta.as_s
        elsif delta = json.dig?("content_block", "text")
          return delta.as_s
        elsif delta = json.dig?("delta", "thinking")
          return delta.as_s
        elsif delta = json.dig?("content_block", "thinking")
          return delta.as_s
        elsif delta = json.dig?("delta", "partial_json")
          return delta.as_s
        else
          return nil
        end
      elsif line.starts_with?("event: ")
        return nil
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
