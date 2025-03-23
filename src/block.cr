require "./persona"
module Block
  struct Block
    getter persona_line : Persona::PersonaLine
    getter content : String

    def initialize(persona_line : Persona::PersonaLine, content : String)
      @persona_line = persona_line
      @content = content
    end   
  end
  
  def self.blocks_from_text(text : String)
    blocks = [] of Block
    current_block_text = ""
    current_persona_line = nil
  
    text.each_line do |line|
      if Persona.is_persona_line(line)
        if current_persona_line
          blocks << Block.new(current_persona_line, current_block_text)
          current_block_text = ""
        end
        current_persona_line = Persona.parse_persona_line(line)
      else
        current_block_text += line
      end
    end
  
    blocks << Block.new(current_persona_line, current_block_text) if current_persona_line
    blocks
  end
end