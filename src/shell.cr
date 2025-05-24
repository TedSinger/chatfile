
module Shell
    def self.binary_lines_to_summary(binary_lines : Array(String)) : String
      bytes = binary_lines.join("\n").to_slice
      total_bytes = bytes.size
      if total_bytes <= 64
        "<hexdump of binary output:\n#{bytes.hexdump}\nend of hexdump>"
      else
        head = bytes[0..31].hexdump
        tail = bytes[-31..-1].hexdump
        "<hexdump of binary output:\n#{head}... (#{total_bytes} bytes total)\n#{tail}\nend of hexdump>"
      end
    end

    def self.summarize_binary_output(output : String) : String
      if output.valid_encoding?
        return output
      end
      lines = output.split("\n")
      result = [] of String
      binary_buffer = [] of String

      lines.each do |line|
        if line.valid_encoding?
          # If we had binary data buffered, summarize and flush it
          if !binary_buffer.empty?
            result << binary_lines_to_summary(binary_buffer)
            binary_buffer.clear
          end
          result << line
        else
          binary_buffer << line
        end
      end

      # Handle any remaining binary data
      if !binary_buffer.empty?
        result << binary_lines_to_summary(binary_buffer)
      end

      result.join("\n")
    end

    def self.run_shell_command(command : String, cwd : Path? = nil) : String
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(command, shell: true, output: stdout, error: stderr, chdir: cwd)
      output = summarize_binary_output(stdout.to_s)
      error = summarize_binary_output(stderr.to_s)
      result = "```shell\n$ #{command}"
      result += "\n#{output}" unless output.empty?
      result += "\nstderr: #{error}" unless error.empty?
      result += "\nExit code: #{status.exit_code}" unless status.success?
      result += "\n```"
      result
    end
end
