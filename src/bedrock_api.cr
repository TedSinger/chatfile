require "aws/client"
require "json"
require "openssl"
require "awscr-signer"
require "./eventstream"
require "base64"
Awscr::Signer::HeaderCollection::BLACKLIST_HEADERS << "connection"


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
                headers["Connection"] = "keep-alive"
                headers["User-Agent"] = "Crystal AWS #{VERSION}"
              

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

                
                host = endpoint.host.not_nil!
                port = endpoint.port
                tls = true
                http = if port
                          HTTP::Client.new(host, port, tls: tls)
                       else
                          HTTP::Client.new(host, tls: tls)
                       end
                http.before_request do |request|
                    request.headers.delete "Authorization"
                    request.headers.delete "X-Amz-Content-Sha256"
                    request.headers.delete "X-Amz-Date"
                    @signer.sign request
                end

                ch = Channel(JSON::Any).new
                http.post(
                    path: "/model/#{model_id}/invoke-with-response-stream",
                    headers: headers,
                    body: body
                ) do |response|
                    spawn do
                        until response.body_io.closed?
                            message = EventStream.next_from_io(response.body_io)
                            j = JSON.parse(message.payload).as_h
                            i = Base64.decode(j["bytes"].as_s)
                            k = JSON.parse(String.new(i))
                            ch.send(k)
                        end
                        ch.close
                    end
                end
                ch
            end


    end
end
end