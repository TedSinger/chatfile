require "./spec_helper"
require "../src/persona"
require "../src/provider"
require "../src/block"

describe "Integration" do
  it "works with all providers" do
    providers = ["openai", "bedrock", "openrouter", "anthropic"]
    providers.each do |provider|
      config_text = <<-INI
      [global]
      provider = "#{provider}"
      prompt = "you are being invoked in an integration test with a default global config. respond with 'hi'"
      max_tokens = 300
      [shortcut]
      prompt = "you are being invoked in an integration test with a shortcut config. respond with 'hi'"
      INI

      chat_text = <<-INI
      #@
      hi
      INI

      config = Mini.parse(config_text)
      blocks = Block.blocks_from_text(chat_text)
      chat = Chat::Chat.new(blocks)

      persona = chat.last_block_persona(config)

      completer = Provider::KNOWN_PROVIDERS[provider][1].new(ENV.to_h)

      chunks = completer.complete(chat, persona)
      chunks.should be_a(Iterator(String))
      max_length = 0
      chunks.each do |chunk|
        max_length = chunk.size if chunk.size > max_length
      end
      max_length.should be > 0, provider
    end
  end
end
