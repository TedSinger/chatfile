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
        persona_line = Persona::PersonaLine.parse_persona_line(block.persona_line)

        if index == 0
          roles << Persona::Role::META
        elsif index == 1
          roles << Persona::Role::USER
          previous_role = Persona::Role::USER
        elsif persona_line.inferred_role == Persona::Role::USER
          roles << Persona::Role::USER
          previous_role = Persona::Role::USER
        elsif persona_line.inferred_role == Persona::Role::META
          roles << Persona::Role::META
        elsif persona_line.inferred_role == Persona::Role::AI
          roles << Persona::Role::AI
          previous_role = Persona::Role::AI
        elsif previous_role == Persona::Role::USER
          roles << Persona::Role::AI
          previous_role = Persona::Role::AI
        else
          roles << Persona::Role::USER
          previous_role = Persona::Role::USER
        end
      end
      roles
    end

    private def persona_line_from_meta_blocks
      meta_blocks = @blocks.zip(@roles).select { |block, role| role == Persona::Role::META }
      meta_blocks.map do |block, role|
        Persona::PersonaLine.parse_persona_line(block.persona_line)
      end.reduce(Persona::PersonaLine.zero) do |acc, persona|
        persona << acc
      end
    end

    def conversation_blocks
      conversation = [] of {String, String}
      current_role = nil
      current_text = ""

      @blocks.zip(@roles).each do |block, role|
        next if role == Persona::Role::META || block.content.strip.empty?

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

    def last_block_persona(provider : String, config : Persona::PersonaConfig)
      default_persona = Persona::Persona.zero << config.defaults_by_provider[provider]

      meta_persona_line = persona_line_from_meta_blocks()
      block_persona_line = Persona::PersonaLine.parse_persona_line(@blocks[-1].persona_line)

      deliberate_persona = block_persona_line << meta_persona_line
      default_persona << deliberate_persona.resolve(config)
    end
  end
end
