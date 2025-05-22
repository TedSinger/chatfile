require "./spec_helper"
require "../src/persona"
require "../src/chat"
require "../src/block"
describe "PersonaConfig" do
  it "should be able to merge configs" do
    chat_text = <<-INI
    #@
    hi
    #@ used_shortcut
    INI

    config = Mini.parse(<<-INI
    [global]
    provider = something_global
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
    persona.key_value_pairs["provider"].should eq("something_global")
    persona.key_value_pairs["something_global_and_used_shortcut"].should eq("used_shortcut")
    persona.key_value_pairs["something_global_and_unused_shortcut"].should eq("global")
  end
end