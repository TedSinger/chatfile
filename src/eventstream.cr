require "base64"

module EventStream
    # Each message has this structure:
    #
    #   total_length   : Int32  (4 bytes)
    #   headers_length : Int32  (4 bytes)
    #   prelude_crc    : Int32  (4 bytes)
    #   headers        : Bytes  (headers_length bytes)
    #   payload        : Bytes  (total_length - headers_length - 16 bytes)
    #   message_crc    : Int32  (4 bytes)
    #
    # Note: We read the raw headers block here but do not parse individual header fields
    # or verify CRC.

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

    def self.next_from_io(io : IO) : EventMessage | Nil
        total_length : Int32 = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        headers_length : Int32 = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        prelude_crc = io.read_bytes(Int32, IO::ByteFormat::BigEndian)
        headers_string = io.read_string(headers_length)
        # total_length includes: 4 + 4 + headers_length + payload + 4 for CRC
        # So payload length = total_length - 4(total len) - 4(headers len) - 4(prelude_crc) - headers_length - 4(message CRC)
        payload_length = total_length - 4 - 4 - 4 - headers_length - 4

        if payload_length < 0
            return nil
        end

        payload_string = io.read_string(payload_length)
        message_crc = io.read_bytes(Int32, IO::ByteFormat::BigEndian)

        EventMessage.new(
            total_length,
            headers_length,
            headers_string,
            payload_string,
            message_crc
        )
    end
end