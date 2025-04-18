require "./block"
require "./persona"
require "./bedrock_complete"
require "./chat"
require "./openrouter_complete"

module Chatfile
end

VERSION = "0.1.0"

text = File.read("foo.chat")

blocks = Block.blocks_from_text(text)

chat = Chat::Chat.new(blocks)
persona_json = <<-JSON
{"default":{"prompt":"You are a helpful, but locanic, succinct, and terse assistant.", "max_tokens":"100","temperature":"0.5"}}
JSON
persona_config = Persona.parse_persona_config(persona_json)

if BedrockComplete.can_access
  puts "Using Bedrock"
  chunks = BedrockComplete.bedrock_api_complete(chat, persona_config)
# elsif OpenRouterComplete.can_access
  # puts "Using OpenRouter"
  # chunks = OpenRouterComplete.openrouter_api_complete(chat, persona_config)
else
  raise "No access to OpenRouter or Bedrock"
end
File.open("foo.chat", "a") do |file|
  if !text.ends_with?("\n")
    file.print("\n")
  end
  if !chat.blocks[-1].content.strip.empty?
    file.print("#% ai\n")
    file.flush
  end
  chunks.each do |chunk|
    file.print(chunk)
    file.flush
  end
  if !chat.blocks[-1].content.ends_with?("\n")
    file.print("\n")
  end
  file.print("#% user\n")
  file.flush
end
