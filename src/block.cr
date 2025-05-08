require "./persona"

module Block
  struct Block
    getter persona_line : String
    getter content : String

    def initialize(persona_line : String, content : String)
      @persona_line = persona_line
      @content = content
    end
  end

  def self.blocks_from_text(text : String)
    blocks = [] of Block
    current_block_text = ""
    current_persona_line = nil

    text.each_line do |line|
      if Persona::PersonaLine.is_persona_line(line)
        if current_persona_line
          blocks << Block.new(current_persona_line, current_block_text)
        else
          blocks << Block.new("#% meta", current_block_text)
        end
        current_block_text = ""
        current_persona_line = line
      else
        current_block_text += line + "\n"
      end
    end
    blocks << Block.new(current_persona_line, current_block_text.strip) if current_persona_line
    blocks
  end
end
