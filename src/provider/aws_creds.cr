module Provider
  module AwsCreds
    def self.can_access
      if ENV.has_key?("AWS_ACCESS_KEY_ID") && ENV.has_key?("AWS_SECRET_ACCESS_KEY")
        true
      else
        self.get_config_for_active_profile["credential_process"]?
      end
    end

    def self.get_credentials
      ret = {} of String => String | Nil
      # add in env vars
      ret["AWS_ACCESS_KEY_ID"] = ENV.fetch("AWS_ACCESS_KEY_ID", "")
      ret["AWS_SECRET_ACCESS_KEY"] = ENV.fetch("AWS_SECRET_ACCESS_KEY", "")
      ret["AWS_REGION"] = ENV.fetch("AWS_REGION", ENV.fetch("AWS_DEFAULT_REGION", ""))
      ret["AWS_SESSION_TOKEN"] = ENV.fetch("AWS_SESSION_TOKEN", nil)
      # add in config
      config = get_config_for_active_profile
      if config["credential_process"]?
        credentials_bytes = `#{config["credential_process"]}`.strip
        credentials_hash = JSON.parse(credentials_bytes).as_h
        {
          "AWS_ACCESS_KEY_ID"     => "AccessKeyId",
          "AWS_SECRET_ACCESS_KEY" => "SecretAccessKey",
          "AWS_REGION"            => "Region",
          "AWS_SESSION_TOKEN"     => "SessionToken",
        }.each do |env_key, cred_key|
          if credentials_hash[cred_key]?.try(&.as_s)
            ret[env_key] = credentials_hash[cred_key]?.try(&.as_s) || ret[env_key]
          end
        end
      end
      return ret
    end

    def self.get_config_for_active_profile
      if File.exists?(File.expand_path(ENV["AWS_CONFIG_FILE"]? || "~/.aws/config"))
        config = File.read(File.expand_path(ENV["AWS_CONFIG_FILE"]? || "~/.aws/config"))
        sections = {} of String => Hash(String, String)
        section_name = "default"
        sections[section_name] = {} of String => String

        config.each_line do |line|
          line = line.strip
          next if line.empty? || line.starts_with?("#")

          if line.starts_with?("[") && line.ends_with?("]")
            section_name = line[1..-2].strip
            sections[section_name] = {} of String => String
          elsif line.includes?("=")
            key, value = line.split("=", 2).map(&.strip)
            sections[section_name][key] = value
          end
        end

        return sections["profile #{ENV["AWS_PROFILE"]? || "default"}"]
      end

      return {} of String => String
    end
  end
end
