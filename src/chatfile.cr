require "option_parser"
require "./block"
require "./persona"
require "./completer/bedrock_complete"
require "./completer/openrouter_complete"
require "./chat"
require "./completer/completer"
require "./completer/aws_creds"
module Chatfile
end

VERSION = "0.1.0"

def get_completer(aws_credentials_command : String?, use_bedrock : Bool, use_openrouter : Bool, env : Hash(String, String)) : Completer::Completer
  # first check for an explicit flag
  if use_bedrock
    puts "Using Bedrock because of --bedrock flag"
    return Completer::BedrockComplete::BedrockCompleter.new(Completer::AwsCreds.get_credentials)
  elsif use_openrouter
    puts "Using OpenRouter because of --openrouter flag"
    return Completer::OpenRouterComplete::OpenRouterCompleter.new(env)
    # otherwise check .can_access
  elsif Completer::OpenRouterComplete.can_access
    puts "Using OpenRouter because of .can_access"
    return Completer::OpenRouterComplete::OpenRouterCompleter.new(env)
  elsif Completer::AwsCreds.can_access
    puts "Using Bedrock because of .can_access"
    return Completer::BedrockComplete::BedrockCompleter.new(Completer::AwsCreds.get_credentials)
  else
    raise "No access to OpenRouter or Bedrock"
  end
end

def process_chat_file(filename : String, completer : Completer::Completer)
  text = File.read(filename)
  blocks = Block.blocks_from_text(text)
  chat = Chat::Chat.new(blocks)
  persona_config = Persona.default_config

  chunks = completer.complete(chat, persona_config)

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
  aws_credentials_command = nil
  parser.on("--aws-credentials-command=", "Shell command returning json") do |command|
    aws_credentials_command = command
  end

  use_bedrock = false
  parser.on("--bedrock", "Use Bedrock") do
    use_bedrock = true
  end

  use_openrouter = false
  parser.on("--openrouter", "Use OpenRouter") do
    use_openrouter = true
  end

  parser.unknown_args do |args|
    if args.empty?
      puts parser
      exit(1)
    end
    completer = get_completer(aws_credentials_command, use_bedrock, use_openrouter, ENV.to_h)
    process_chat_file(args[0], completer)
  end
end
