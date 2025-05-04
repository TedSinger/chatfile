require "./block"
require "./persona"

module Chat
  class Chat
    getter blocks : Array(Block::Block)
    getter roles : Array(String)

    def initialize(blocks : Array(Block::Block))
      @blocks = blocks
      @roles = infer_roles(blocks)
    end

    private def infer_roles(blocks : Array(Block::Block)) : Array(String)
      roles = [] of String
      previous_role = nil

      blocks.each_with_index do |block, index|
        persona_line = block.persona_line

        if index == 0
          roles << Role::META
        elsif index == 1
          roles << Role::USER
          previous_role = Role::USER
        elsif persona_line.keywords.includes?("user")
          roles << Role::USER
          previous_role = Role::USER
        elsif persona_line.keywords.includes?("meta")
          roles << Role::META
        elsif persona_line.keywords.includes?("brainstorm") || persona_line.keywords.includes?("ai")
          roles << Role::AI
          previous_role = Role::AI
        elsif previous_role == Role::USER
          roles << Role::AI
          previous_role = Role::AI
        else
          roles << Role::USER
          previous_role = Role::USER
        end
      end
      roles
    end

    private def fragment_from_meta_blocks(persona_config : Persona::PersonaConfig)
      @blocks.zip(@roles).select { |block, role| role == Role::META }.map do |block, role|
        block.persona_line.to_persona_and_fragment(persona_config)[1]
      end.reduce(Persona::PersonaFragment.zero_persona) do |acc, fragment|
        acc.merge_on_top_of(fragment)
      end
    end

    def conversation_blocks
      conversation = [] of {String, String}
      current_role = nil
      current_text = ""

      @blocks.zip(@roles).each do |block, role|
        next if role == Role::META || block.content.strip.empty?

        if role == current_role
          current_text += " " + block.content.strip
        else
          conversation << {current_role, current_text} if current_role
          current_role = role
          current_text = block.content.strip
        end
      end

      conversation << {current_role, current_text} if current_role
      conversation
    end

    def last_block_persona(provider_default_params : Persona::PersonaFragment, persona_config : Persona::PersonaConfig)
      block_persona, block_fragment = @blocks[-1].persona_line.to_persona_and_fragment(persona_config)

      meta_fragment = fragment_from_meta_blocks(persona_config)
      # FIXME: model might be configured by the block persona (Explicitly or through the character)
      model_config_params = persona_config[provider_default_params.key_value_pairs["model"]] || Persona::PersonaFragment.zero_persona
      default_persona = persona_config["default"] || Persona::PersonaFragment.zero_persona
      block_fragment.merge_on_top_of(meta_fragment).merge_on_top_of(block_persona).merge_on_top_of(default_persona).merge_on_top_of(model_config_params).merge_on_top_of(provider_default_params)
    end
  end
end

module Role
  USER = "user"
  META = "meta"
  AI   = "ai"
end
