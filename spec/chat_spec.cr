require "./spec_helper"
require "../src/chat"
require "../src/block"
require "../src/persona"
require "../src/persona_config"

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
end
