require "./mini"

module PersonaConfig
  alias PersonaConfig = Hash(String, Hash(String, String))

  def self.merge(a : PersonaConfig, b : PersonaConfig)
    a.merge(b) { |_, v1, v2| v1.merge(v2) }
  end

  def self.default_path
    File.expand_path("~/.config/chatfile/personas.ini", home: Path.home)
  end

  def self.maybe_create_default_config
    default = self.default_config
    if !File.exists?(self.default_path)
      File.write(self.default_path, self.default_config_text)
      puts "Created #{self.default_path}"
    end
  end

  macro add_default_config_text
    def self.default_config_text : String
        {{ read_file("#{__DIR__}/default_config.ini") }}
    end
  end

  add_default_config_text

  def self.default_config : PersonaConfig
    Mini.parse(default_config_text)
  end

  def self.get : PersonaConfig
    if File.exists?(self.default_path)
      begin
        self.merge(self.default_config, Mini.parse(File.read(self.default_path)))
      rescue e
        puts "Error parsing default config: #{e}"
        self.default_config
      end
    else
      self.default_config
    end
  end
end
