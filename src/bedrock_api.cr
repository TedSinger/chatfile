require "aws/client"
require "json"
require "openssl"
require "awscr-signer"
require "crest"

module AWS
    module BedrockRuntime
        class Client < AWS::Client
            SERVICE_NAME = "bedrock-runtime"
            def initialize(
                    @access_key_id = AWS.access_key_id,
                    @secret_access_key = AWS.secret_access_key,
                    @region = AWS.region,
                    @endpoint = URI.parse("https://bedrock-runtime.#{region}.amazonaws.com"),
                )
                @signer = Awscr::Signer::Signers::V4.new("bedrock", region, access_key_id, secret_access_key)
                @connection_pools = Hash({String, Int32?, Bool}, DB::Pool(HTTP::Client)).new
            end
          
            
            def invoke_model_with_response_stream(
                model_id : String,
                body : String,
                accept : String = "application/json",
                content_type : String = "application/json",
                guardrail_identifier : String? = nil,
                guardrail_version : String? = nil,
                performance_config_latency : String? = nil,
                trace : String? = nil
            )
                headers = HTTP::Headers.new
                headers["X-Amzn-Bedrock-Accept"] = accept
                headers["Content-Type"] = content_type

                if guardrail_identifier
                    headers["X-Amzn-Bedrock-GuardrailIdentifier"] = guardrail_identifier
                end

                if guardrail_version
                    headers["X-Amzn-Bedrock-GuardrailVersion"] = guardrail_version
                end

                if performance_config_latency
                    headers["X-Amzn-Bedrock-PerformanceConfig-Latency"] = performance_config_latency
                end

                if trace
                    headers["X-Amzn-Bedrock-Trace"] = trace
                end

                # add_aws_headers(headers, model_id, body)

                response = http(&.post(
                    path: "/model/#{model_id}/invoke-with-response-stream",
                    headers: headers,
                    body: body
                ))

                if response.success?
                    Response.new(response)
                else
                    raise "AWS::BedrockRuntime#invoke_model_with_response_stream: #{response.body}"
                end
            end

        class Response
            getter response : HTTP::Client::Response
            getter content_type : String
            getter performance_config_latency : String?

            def initialize(@response : HTTP::Client::Response)
                @content_type = @response.headers["X-Amzn-Bedrock-Content-Type"]? || "application/json"
                @performance_config_latency = @response.headers["X-Amzn-Bedrock-PerformanceConfig-Latency"]?
            end

            def chunks
                if !@response.success?
                    raise "AWS::BedrockRuntime#invoke_model_with_response_stream: #{@response.body}"
                end
                puts @response.status_message
                puts @response.headers
                puts @response.body
                ch = Channel(JSON::Any).new
                spawn do
                    # puts @response.body
                    @response.body_io.each_line do |line|
                        if line
                            puts line
                            ch.send(JSON.parse(line))
                        end
                    end
                    ch.close
                end
                ch
            end
        end

    end
end
end