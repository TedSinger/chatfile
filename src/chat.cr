module Chat
  class Chat
    def initialize(blocks : Array(Block))
      @blocks = blocks
      @roles = infer_roles(blocks)
    end

    private def infer_roles(blocks : Array(Block)) : Array(Role)
      roles = [] of Role
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
  end
end

module Role
  USER = "user"
  META = "meta"
  AI = "ai"
end