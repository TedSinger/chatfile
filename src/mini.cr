module Mini
  # Like INI but with multi-line values
  def self.parse(content : String) : Hash(String, Hash(String, String))
    result = {} of String => Hash(String, String)
    current_section = nil
    current_key = nil
    current_multi_line_prefix = nil
    content.each_line do |line|
      next if line.starts_with?('#') || line.starts_with?(';')
      # handle multi-line values, indicated by a whitespace prefix
      if line.match(/^(\s+)/) && !current_multi_line_prefix && current_key
        current_multi_line_prefix = line.match(/^(\s+)/).not_nil![0]
        line = line.lchop(current_multi_line_prefix)
        result[current_section.not_nil!][current_key.not_nil!] += "\n#{line.rstrip}"
      elsif current_multi_line_prefix && line.starts_with?(current_multi_line_prefix)
        line = line.lchop(current_multi_line_prefix)
        result[current_section.not_nil!][current_key.not_nil!] += "\n#{line.rstrip}"
      elsif line.starts_with?('[')
        if line.ends_with?(']')
          if current_multi_line_prefix && current_section && current_key
            # fix accidental trailing whitespace on multi-line values
            result[current_section][current_key] = result[current_section][current_key].rstrip
          end
          current_multi_line_prefix = nil
          current_key = nil
          current_section = line[1..-2].strip
          result[current_section] = {} of String => String
        else
          raise "Invalid section header: #{line}"
        end
      elsif line.includes?('=') && current_section
        current_multi_line_prefix = nil
        key, value = line.split('=', 2).map(&.strip)
        current_key = key
        result[current_section][key] = value
      elsif !line.strip.empty?
        raise "Invalid line: #{line}"
      end
    end
    if current_section == nil
      raise "No sections found (expected [some_name]...)"
    end

    result
  end
end
