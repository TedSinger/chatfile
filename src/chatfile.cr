require "./block"
require "./persona"
require "./bedrock"
require "./chat"

module Chatfile
end

VERSION = "0.1.0"

example_text = <<-TEXT
#% user
Kindly relate a humorous anecdote regarding a jungle fowl and a transit corridor
#% brainstorm temperature=1.0
Any number of cliched jokes about a chicken crossing the road would fit. But the user's word choice is oddly technical. Let's try something more futuristic

TEXT

blocks = Block.blocks_from_text(example_text)
blocks.each do |block|
  puts "Persona Line: #{block.persona_line.keywords.join(", ")}"
  puts "Content: #{block.content.strip}"
  puts "Key-Value Pairs: #{block.persona_line.key_value_pairs}"
  puts "-----------------------------"
end
text = File.read("foo.chat")

blocks = Block.blocks_from_text(text)

chat = Chat::Chat.new(blocks)
persona_json = <<-JSON
{"default":{"prompt":"You are a helpful assistant.", "max_tokens":"100","temperature":"0.5"}}
JSON
persona_config = Persona.parse_persona_config(persona_json)


chunks = Bedrock.bedrock_api_complete(chat, persona_config)
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
