require "./spec_helper"
require "../src/chat"
require "../src/block"
require "../src/persona"
require "../src/persona_config"
require "json"
describe "Chat" do
  it "runs shell commands" do
    chat_text = <<-INI
    #@ $
    echo "hello"
    INI

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    result = chat.conversation_blocks
    result.should eq([{"user", "```shell\n$ echo \"hello\"\nhello\n\n```"}])
  end
  it "infers the first block's persona" do
    chat_text = <<-INI
    #@ $
    echo "hello"
    INI

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    result = chat.roles
    result.should eq([Persona::Role::META, Persona::Role::SHELL])
  end
  it "infers many roles" do
    chat_text = <<-INI
    #@ $
    echo "hello"
    #@
    echo "world"
    #@
    echo "foo"
    INI

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    result = chat.roles
    result.should eq([Persona::Role::META, Persona::Role::SHELL, Persona::Role::AI, Persona::Role::USER])
  end
  it "tolerates shell commands with binary output" do
    chat_text = <<-INI
    #@ $
    echo hello; echo world; head -c 100 /dev/urandom | gzip --stdout -f; echo bar | gzip --stdout -f; echo goodbye; echo globe
    INI

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    result = chat.conversation_blocks
    text = result.last[1]
    text.valid_encoding?.should be_true
    text.should match(/hello\nworld/)
  end
  it "infers the last block's persona as USER if ambiguous" do
    chat_text = <<-INI
    #@ $
    echo "hello"
    #@
    what was the last command?
    INI

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    result = chat.roles
    result.should eq([Persona::Role::META, Persona::Role::SHELL, Persona::Role::USER])
  end
end
