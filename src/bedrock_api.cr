require "aws/client"
require "json"
require "awscr-signer"
require "./eventstream"
require "base64"

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
          
            
            def generic_event_to_bedrock_event(event : EventStream::EventMessage) : JSON::Any
                j = JSON.parse(event.payload).as_h
                i = Base64.decode(j["bytes"].as_s)
                JSON.parse(String.new(i))
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


                ch = Channel(JSON::Any).new
                http do |http|
                    http.post(
                        path: "/model/#{model_id}/invoke-with-response-stream",
                        headers: headers,
                        body: body
                    ) do |response|
                        spawn do
                            until response.body_io.closed?
                                message = EventStream.next_from_io(response.body_io)
                                if message
                                    ch.send(generic_event_to_bedrock_event(message))
                                end
                            end
                            ch.close
                        end
                    end
                end
                ch
            end
        end
    end
end