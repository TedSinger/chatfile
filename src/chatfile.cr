require "./block"
require "./persona"
require "./bedrock"
require "./chat"
require "./openai_complete"

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


chunks = OpenAIComplete.openai_api_complete(chat, persona_config)
File.open("foo.chat", "a") do |file|
  if !chat.blocks[-1].content.strip.empty?
    file.print("\n#% ai\n")
    file.flush
  end
  loop do
    chunk = chunks.receive?
    break if chunk == nil
    print chunk
    file.print(chunk)
    file.flush
  end
  file.print("\n#% user\n")
  file.flush
end
