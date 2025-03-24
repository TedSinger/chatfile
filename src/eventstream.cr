require "base64"

module EventStream
    # Minimal example of parsing AWS event stream messages in Crystal.
    # Each message has this structure (all fields in big-endian by AWS spec):
    #
    #   total_length   : Int32  (4 bytes)
    #   headers_length : Int32  (4 bytes)
    #   headers        : Bytes  (headers_length bytes)
    #   payload        : Bytes  (total_length - headers_length - 16 bytes)
    #   message_crc    : Int32  (4 bytes)
    #
    # Note: We read the raw headers block here but do not parse individual header fields
    # or verify CRC. Adjust endianness and further parsing as needed.

    struct EventMessage
        getter total_length     : Int32
        getter headers_length   : Int32
        getter headers          : String
        getter payload          : String
        getter message_crc      : Int32

        def initialize(@total_length : Int32, @headers_length : Int32, @headers : String, @payload : String, @message_crc : Int32)
            @total_length = total_length
            @headers_length = headers_length
            @headers = headers
            @payload = payload
            @message_crc = message_crc
        end

        
    end
    def self.next_from_io(io : IO) : EventMessage
        # Try to read total_length
        total_length : Int32 = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        # puts "total_length: #{total_length}"
        # Next, headers_length
        headers_length : Int32 = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        # puts "headers_length: #{headers_length}"

        prelude_crc = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        # puts "prelude_crc: #{prelude_crc}"

        # Then the raw headers block
        headers_string = io.read_string(headers_length)
        # puts "headers_string: #{headers_string}"
        # Calculate how many bytes remain for payload: 
        # total_length includes: 4 + 4 + headers_length + payload + 4 for CRC
        # So payload length = total_length - 4(header len) - 4(headers len) - headers_length - 4(CRC)
        payload_length = total_length - 4 - 4 -4 - headers_length - 4
        #puts "payload_length: #{payload_length}"
        if payload_length < 0
            return next_from_io(io)
        end

        # Now read the payload
        payload_string = io.read_string(payload_length)
        # puts "payload_string: #{payload_string}"
        # Finally the CRC
        message_crc = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        # puts "message_crc: #{message_crc}"

        # Construct the event message object
        EventMessage.new(
            total_length,
            headers_length,
            headers_string,
            payload_string,
            message_crc
        )
    end
end