require "./block"
require "./persona"

module Chat
  class Chat
    getter blocks : Array(Block::Block)
    getter roles : Array(String)
    getter conversation : Array(Tuple(String, String))

    def initialize(blocks : Array(Block::Block))
      @blocks = blocks
      @roles = infer_roles(blocks)
      @conversation = conversation_blocks
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
        elsif persona_line.inferred_role == Persona::Role::SHELL
          roles << Persona::Role::SHELL
          previous_role = Persona::Role::USER
        elsif persona_line.inferred_role == Persona::Role::META
          roles << Persona::Role::META
        elsif persona_line.inferred_role == Persona::Role::JSON_RESPONSE_FORMAT
          roles << Persona::Role::JSON_RESPONSE_FORMAT
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
        acc << persona
      end
    end

    private def run_shell_command(command : String, cwd : String? = nil) : String
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(command, shell: true, output: stdout, error: stderr, chdir: cwd)
      output = stdout.to_s
      error = stderr.to_s
      result = "```shell\n$ #{command}"
      result += "\n#{output}" unless output.empty?
      result += "\nstderr: #{error}" unless error.empty?
      result += "\nExit code: #{status.exit_code}" unless status.success?
      result += "\n```"
      result
    end

    def conversation_blocks
      conversation = [] of {String, String}
      current_role = nil
      current_text = ""

      @blocks.zip(@roles).each do |block, role|
        next if role == Persona::Role::META || role == Persona::Role::JSON_RESPONSE_FORMAT || block.content.strip.empty?
        if role == current_role
          current_text += " " + block.content.strip
        else
          conversation << {current_role, current_text} if current_role
          if role == Persona::Role::SHELL
            cwd = nil
            Persona::PersonaLine.parse_persona_line(block.persona_line).keywords.each do |keyword|
              if File.exists?(Path[keyword].expand(home: true))
                cwd = keyword
              end
            end
            current_role = Persona::Role::USER
            lines = block.content.strip.split("\n")
            current_text = lines.map do |line|
              run_shell_command(line, cwd)
            end.join("\n")
          else
            current_role = role
            current_text = block.content.strip
          end
        end
      end

      conversation << {current_role, current_text} if current_role
      conversation
    end

    def last_block_persona(provider : String, config : Persona::PersonaConfig)
      default_persona = Persona::Persona.zero << config.defaults_by_provider[provider]
      meta_persona_line = persona_line_from_meta_blocks()
      block_persona_line = Persona::PersonaLine.parse_persona_line(@blocks[-1].persona_line)

      deliberate_persona = meta_persona_line << block_persona_line
      result = default_persona << deliberate_persona.resolve(config)
      result
    end

    def response_format : JSON::Any?
      format_blocks = @blocks.zip(@roles).select { |block, role| role == Persona::Role::JSON_RESPONSE_FORMAT }
      if format_blocks.empty?
        nil
      else
        last_format = format_blocks.last[0].content.strip
        begin
          JSON.parse(last_format)
        rescue JSON::ParseException
          raise "Invalid JSON in response_format block: #{last_format}"
        end
      end
    end
  end
end
