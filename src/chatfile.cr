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
#% assistant
What motivation compelled the RoosterBot to trespass across the hyperlane? To access the excluded zone!
TEXT

blocks = Block.blocks_from_text(example_text)
blocks.each do |block|
  puts "Persona Line: #{block.persona_line.keywords.join(", ")}"
  puts "Content: #{block.content.strip}"
  puts "Key-Value Pairs: #{block.persona_line.key_value_pairs}"
  puts "-----------------------------"
end

chat = Chat::Chat.new(blocks)
persona_config = {
  "max_tokens" => 1000,
  "temperature" => 0.5,
}

channel = Channel(String).new
spawn do
  Bedrock.bedrock_api_complete(chat, persona_config, channel)
end

spawn do
  loop do
    message = channel.receive?
    break unless message
    puts message
  end
end
Fiber.yield