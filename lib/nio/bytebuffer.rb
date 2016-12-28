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
      raise OverflowError, "buffer is full" if str.length > @limit - @position
      @buffer[@position...str.length] = str
      @position += str.length
      self
    end

    # Perform a non-blocking read from the given IO object into the buffer
    # Reads as much data as is immediately available and returns
    #
    # @param [IO] Ruby IO object to read from
    #
    # @return [Integer] number of bytes read (0 if none were available)
    def read_from(io)
      nbytes = @limit - @position
      raise OverflowError, "buffer is full" if nbytes.zero?

      bytes_read = IO.try_convert(io).read_nonblock(nbytes, exception: false)
      return 0 if bytes_read == :wait_readable

      self << bytes_read
      bytes_read.length
    end

    # Perform a non-blocking write of the buffer's contents to the given I/O object
    # Writes as much data as is immediately possible and returns
    #
    # @param [IO] Ruby IO object to write to
    #
    # @return [Integer] number of bytes written (0 if the write would block)
    def write_to(io)
      nbytes = @limit - @position
      raise UnderflowError, "no data remaining in buffer" if nbytes.zero?

      bytes_written = IO.try_convert(io).write_nonblock(@buffer[@position...@limit], exception: false)
      return 0 if bytes_written == :wait_writable

      @position += bytes_written
      bytes_written
    end

    # Set the buffer's current position as the limit and set the position to 0
    def flip
      @limit = @position
      @position = 0
      @mark = -1
      self
    end

    # Set the buffer's current position to 0, leaving the limit unchanged
    def rewind
      @position = 0
      @mark = -1
      self
    end

    # mark the current position in order to reset later
    def mark
      @mark = @position
    end

    # reset the position to the previously marked position
    def reset
      raise "Invalid Mark Exception" if @mark < 0
      @position = @mark
      self
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
