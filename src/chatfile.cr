require "option_parser"
require "./block"
require "./persona"
require "./completer/bedrock_complete"
require "./completer/openrouter_complete"
require "./completer/openai_completer"
require "./chat"
require "./completer/completer"
require "./completer/aws_creds"

module Chatfile
end

VERSION = "0.1.0"


def process_chat_file(filename : String, completer : Completer::Completer)
  text = File.read(filename)
  blocks = Block.blocks_from_text(text)
  chat = Chat::Chat.new(blocks)
  if chat.conversation.empty?
    puts "No conversation blocks found. Try writing a block like this:"
    puts "#@"
    puts "hi"
    return 1
  end
  persona_config = Persona::PersonaConfig.default_config
  begin
    chunks = completer.complete(chat, persona_config)
  rescue e : Completer::CompleterError
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

  unless File.exists?(config_file)
    File.write(config_file, {
      "defaults_by_provider" => {
        "openrouter" => {"model" => "openai/gpt-4-turbo-preview", "max_tokens" => "1000"},
        "bedrock"    => {"model" => "us.anthropic.claude-3-7-sonnet-20250219-v1:0"},
        "openai"     => {"model" => "gpt-4o-mini", "max_tokens" => "1000"},
      },
      "shortcuts" => {"shakespeare" => {"prompt" => "You are the bard of Avon, loquacious poet", "temperature" => "1.5"}, "spock" => {"prompt" => "You are Spock, the logical Vulcan", "temperature" => "0.2"}},
    }.to_pretty_json)
    puts "Created ~/.config/chatfile/personas.json"
  end
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

  if Completer::OpenRouter.can_access
    puts "OpenRouter is available!"
  elsif Completer::AwsCreds.can_access
    puts "Bedrock is available!"
  elsif Completer::OpenAI.can_access
    puts "OpenAI is available!"
  else
    puts "No providers are available. Try setting OPENROUTER_API_KEY, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, or OPENAI_API_KEY"
  end
end

def provider_from_flag(arg : String)
  if Completer::KNOWN_PROVIDERS.includes?(arg)
    arg
  else
    options = "{" + Completer::KNOWN_PROVIDERS.join(", ") + "}"
    raise "Unknown provider: #{arg}. Try --provider=#{options}."
  end
end

OptionParser.parse do |parser|
  parser.banner = "Usage: chatfile [arguments] <filename>"

  parser.on("--get-started", "Create a default config file and example `chatfile`") do
    get_started
    exit
  end

  flag_provider = nil
  provider_help = "Use a specific provider. Known providers: #{Completer::KNOWN_PROVIDERS.join(", ")}\n  Respects env-var $CHATFILE_PROVIDER otherwise"
  parser.on("-p PROVIDER", "--provider=PROVIDER", provider_help) do |arg|
    begin
      flag_provider = provider_from_flag(arg)
    rescue e : Exception
      puts "Error: #{e}"
      exit(1)
    end
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
    completer = Completer.get_completer(flag_provider, ENV.to_h)
    ret = process_chat_file(args[0], completer)
    exit(ret)
  end
end
