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

VERSION = "0.1.0"

def process_chat_file(filename : String, completer : Provider::Completer)
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
  persona_config = PersonaConfig.get
  begin
    chunks = completer.complete(chat, persona_config)
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
  config_dir = Path["~/.config/chatfile"].expand(home: true)
  Dir.mkdir_p(config_dir)
  config_file = config_dir / "personas.json"

  PersonaConfig.maybe_create_default_config

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
    puts "No providers are available. Try setting OPENROUTER_API_KEY, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, or OPENAI_API_KEY"
  end
end

def requested_provider(arg : String?, env : Hash(String, String))
  options = "{" + Provider::KNOWN_PROVIDERS.keys.join(", ") + "}"
  selection = arg ? arg : env["CHATFILE_PROVIDER"]?
  reason = arg ? "flag" : "$CHATFILE_PROVIDER"
  if selection
    if Provider::KNOWN_PROVIDERS.keys.includes?(selection)
      puts "Using #{selection} because of #{reason}"
      return selection
    else
      raise "Unknown provider: #{selection}. Try --provider=#{options}."
    end
  end
  nil
end

OptionParser.parse do |parser|
  parser.banner = "Usage: chatfile [arguments] <filename>"

  parser.on("--get-started", "Create a default config file and example `chatfile`") do
    get_started
    exit
  end

  provider_name = nil
  provider_help = "Use a specific provider. Known providers: #{Provider::KNOWN_PROVIDERS.keys.join(", ")}\n  Respects env-var $CHATFILE_PROVIDER otherwise"
  parser.on("-p PROVIDER", "--provider=PROVIDER", provider_help) do |arg|
    provider_name = arg
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
    begin
      provider = requested_provider(provider_name, ENV.to_h)
      completer = Provider.get_completer(provider, ENV.to_h)
    rescue e : Exception
      puts "Error: #{e}"
      exit(1)
    end
    ret = process_chat_file(args[0], completer)
    exit(ret)
  end
end
