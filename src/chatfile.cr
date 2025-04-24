require "option_parser"
require "./block"
require "./persona"
require "./bedrock_complete"
require "./chat"
require "./openrouter_complete"

module Chatfile
end

VERSION = "0.1.0"

def process_chat_file(filename : String)
  text = File.read(filename)
  blocks = Block.blocks_from_text(text)
  chat = Chat::Chat.new(blocks)
  persona_config = Persona.default_config

  chunks = if OpenRouterComplete.can_access
    puts "Using OpenRouter"
    OpenRouterComplete.openrouter_api_complete(chat, persona_config)
  elsif BedrockComplete.can_access
    puts "Using Bedrock" 
    BedrockComplete.bedrock_api_complete(chat, persona_config)
  else
    raise "No access to OpenRouter or Bedrock"
  end

  File.open(filename, "a") do |file|
    file.print("\n") unless text.ends_with?("\n")
    
    if !chat.blocks[-1].content.strip.empty?
      file.print("#% ai\n")
      file.flush
    end

    chunks.each do |chunk|
      file.print(chunk)
      file.flush
    end

    file.print("\n") unless chat.blocks[-1].content.ends_with?("\n")
    file.print("#% user\n")
    file.flush
  end
end

# Parse command line arguments
OptionParser.parse do |parser|
  parser.banner = "Usage: chatfile [arguments] <filename>"

  parser.on("-v", "--version", "Show version") do
    puts "Chatfile version #{VERSION}"
    exit
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.unknown_args do |args|
    if args.empty?
      puts parser
      exit(1)
    end
    process_chat_file(args[0])
  end
end
