module NIO
  # Efficient byte buffers for performant I/O operations
  class ByteBuffer
    attr_reader :position, :limit, :capacity

    # Insufficient capacity in buffer
    OverflowError = Class.new(IOError)

    # Not enough data remaining in buffer
    UnderflowError = Class.new(IOError)

    # Create a new ByteBuffer, either with a specified capacity or populating
    # it from a given string
    #
    # @param capacity [Integer] size of buffer in bytes
    #
    # @return [NIO::ByteBuffer]
    def initialize(capacity)
      raise TypeError, "no implicit conversion of #{capacity.class} to Integer" unless capacity.is_a?(Integer)
      @capacity = capacity
      clear
    end

    # Clear the buffer, resetting it to the default state
    def clear
      @buffer   = "\0".force_encoding(Encoding::BINARY) * @capacity
      @position = 0
      @limit    = @capacity
      @mark     = nil

      self
    end

    # Number of bytes remaining in the buffer before the limit
    #
    # @return [Integer] number of bytes remaining
    def remaining
      @limit - @position
    end

    # Does the ByteBuffer have any space remaining?
    #
    # @return [true, false]
    def full?
      remaining.zero?
    end

    # Obtain the requested number of bytes from the buffer, advancing the position
    #
    # @raise [NIO::ByteBuffer::UnderflowError] not enough data remaining in buffer
    #
    # @return [String] bytes read from buffer
    def get(length)
      raise ArgumentError, "negative length given" if length < 0
      raise UnderflowError, "not enough data in buffer" if length > @limit - @position

      result = @buffer[@position...length]
      @position += length
      result
    end

    # Add a String to the buffer
    #
    # @raise [NIO::ByteBuffer::OverflowError] buffer is full
    #
    # @return [self]
    def <<(str)
      raise OverflowError, "buffer is full" if str.length > @capacity - @position
      @buffer[@position...str.length] = str
      @position += str.length
      self
    end

    # write content in the buffer to file
    # call flip before calling this
    # after write operation to the
    # buffer
    def write_to(file)
      @file_to_write = file unless @file_to_write.eql? file
      file.write get if remaining?
    end

    # Fill the byteBuffer with content of the file
    def read_from(file)
      @file_to_read = file unless @file_to_read.eql? file
      while (s = file.read(1)) && remaining?
        put_byte(s)
      end
    end

    # Flip the buffer over, preparing it to be read
    def flip
      @limit = @position
      @position = 0
      @mark = -1
    end

    # rewind read mode to write mode. limit stays unchanged
    def rewind
      @position = 0
      @mark = -1
    end

    # reset the position to the previously marked position
    def reset
      raise "Invalid Mark Exception" if @mark < 0
      @position = @mark
      self
    end

    # mark the current position in order to reset later
    def mark
      @mark = @position
    end

    def to_s
      # convert String in byte form to the visible string
      temp = "ByteBuffer "
      temp += "[pos=" + @position.to_s
      temp += " lim =" + @limit.to_s
      temp += " cap=" + @capacity.to_s
      temp += "]"
      temp
    end
  end
end
