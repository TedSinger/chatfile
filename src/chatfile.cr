require "option_parser"
require "./block"
require "./persona"
require "./persona_config"
require "./provider/bedrock"
require "./provider/openrouter"
require "./provider/openai"
require "./provider/anthropic"
require "./chat"
require "./provider/provider"
require "./provider/aws_creds"

module Chatfile
end

VERSION = "wffm"

def process_chat_file(filename : String)
  text = File.read(filename)
  blocks = Block.blocks_from_text(text)
  chat = Chat::Chat.new(blocks)
  if chat.conversation.empty?
    puts "No conversation blocks found. Try writing a block like this:"
    puts "#@"
    puts "hi"
    return 1
  elsif chat.conversation.last[0] == "ai"
    puts "Last block is an AI block. Nothing to do"
    return 0
  end
  persona = chat.last_block_persona(PersonaConfig.get)
  begin
    provider = persona.key_value_pairs["provider"]? || Provider.get_any_available(ENV.to_h)
    completer = Provider::KNOWN_PROVIDERS[provider][1].new(ENV.to_h)
    chunks = completer.complete(chat, persona)
  rescue e : Provider::CompleterError
    puts "Error: #{e}"
    return 1
  end

  File.open(filename, "a") do |file|
    # FIXME: This is all abstraction-violating hackery
    file.print("\n") unless text.ends_with?("\n")

    if !chat.blocks[-1].content.strip.empty?
      file.print("#@ ai\n")
      file.flush
    end

    chunks.each do |chunk|
      file.print(chunk)
      file.flush
    end

    file.print("\n") unless chat.blocks[-1].content.ends_with?("\n")
    file.print("#@\n")
    file.flush
  end
  0
end

def get_started
  PersonaConfig.maybe_create_default_config
  puts "Created #{PersonaConfig.default_path}"

  unless File.exists?("example.chat")
    File.write("example.chat", <<-CHAT
    #!/usr/bin/env chatfile
    #@ user
    What's the situation out there, Mister Spock?
    #@ shakespeare
    The fighter, like a hawk upon the wing,
    Doth strike with purpose, aiming to ensnare,
    To silence engines that still whisper life,
    And snuff the flick'ring flame of hope within.
    'Tis a tale of treachery, borne of dark desire,
    Where life and death do waltz upon the edge of a blade.
    #@
    Come again?
    #@ spock
    CHAT
    )
  end
  File.chmod("example.chat", 0o744)

  puts "Created example.chat"
  puts "Edit example.chat and run it with `chatfile example.chat`"
  puts "Or if `chatfile` is in your PATH, you can run the chat directly with `./example.chat`"
  found_provider = false
  Provider::KNOWN_PROVIDERS.each do |provider_name, provider|
    if provider[0].can_access(ENV.to_h)
      puts "#{provider_name} is available!"
      found_provider = true
    end
  end
  if !found_provider
    puts "No providers are available. Try setting OPENROUTER_API_KEY, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, OPENAI_API_KEY, or ANTHROPIC_API_KEY"
  end
end

OptionParser.parse do |parser|
  parser.banner = "Usage: chatfile <filename>"

  parser.on("--get-started", "Create a default config file and example `chatfile`") do
    get_started
    exit
  end

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
    ret = process_chat_file(args[0])
    exit(ret)
  end
end
