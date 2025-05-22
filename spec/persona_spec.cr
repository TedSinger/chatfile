require "./spec_helper"
require "../src/persona"
require "../src/chat"
require "../src/block"
describe "Persona" do
  it "uses shortcuts" do
    chat_text = <<-INI
    #@
    hi
    #@ used_shortcut
    INI

    config = Mini.parse(<<-INI
    [global]
    something_global = something_global
    something_global_and_used_shortcut = global
    something_global_and_unused_shortcut = global
    [used_shortcut]
    something_global_and_used_shortcut = used_shortcut
    [unused_shortcut]
    something_global_and_unused_shortcut = unused_shortcut
    INI
    )

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    persona = chat.last_block_persona(config)
    persona.key_value_pairs["something_global"].should eq("something_global")
    persona.key_value_pairs["something_global_and_used_shortcut"].should eq("used_shortcut")
    persona.key_value_pairs["something_global_and_unused_shortcut"].should eq("global")
  end

  it "uses only the last block's shortcut" do
    chat_text = <<-INI
    #@
    hi
    #@ shortcut
    hi
    #@ last_block
    hi
    INI

    config = Mini.parse(<<-INI
    [global]
    something_global = something_global
    [shortcut]
    something_global = shortcut
    [last_block]
    something_global = last_block
    INI
    )

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    persona = chat.last_block_persona(config)
    persona.key_value_pairs["something_global"].should eq("last_block")
  end
  it "includes k=v pairs in the last block" do
    chat_text = <<-INI
    #@
    hi
    #@ last_block k=pair last_block
    hi
    INI

    config = Mini.parse(<<-INI
    [global]
    k = global
    [last_block]
    k = last_block
    INI
    )

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    persona = chat.last_block_persona(config)
    persona.key_value_pairs["k"].should eq("pair")
  end
  it "propagates anything from META blocks" do
    chat_text = <<-INI
    #@
    hi
    #@ meta k=meta1 l=meta2
    #@ meta l=meta4
    #@ last_block
    hi
    INI

    config = Mini.parse(<<-INI
    [global]
    k = global
    [last_block]
    k = last_block
    INI
    )

    blocks = Block.blocks_from_text(chat_text)
    chat = Chat::Chat.new(blocks)
    persona = chat.last_block_persona(config)
    persona.key_value_pairs["k"].should eq("meta1")
    persona.key_value_pairs["l"].should eq("meta4")
  end
end
