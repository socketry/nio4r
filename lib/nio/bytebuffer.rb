module NIO
  class ByteBuffer
    attr_reader :size

    # Create a new ByteBuffer, either with a specified capacity or populating
    # it from a given string
    #
    # @param capacity [Integer] size of buffer in bytes
    #
    # @return [NIO::ByteBuffer]
    def initialize(capacity)
      raise TypeError, "expected Integer argument, got #{capacity.class}" unless capacity.is_a?(Integer)

      @size       = capacity
      @byte_array = Array.new(capacity)
      @position   = 0
      @mark       = -1
      @limit      = @size - 1
    end

    # put the provided string to the buffer
    def <<(str)
      str.bytes.each { |x| put_byte x }
    end

    # return the remaining number positions to read/ write
    def remaining
      @limit + 1 - @position
    end

    # has any space remaining
    def remaining?
      remaining > 0
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

    # flip from write to read mode
    def flip
      # need to avoid @position being negative
      @limit = [@position - 1, 0].max
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

    # the current values are considered junk
    def clear
      @position = 0
      @limit = @size - 1
      @mark = -1
      self
    end

    def compact
      # compact should be allowed only if there are content remaining in the buffer
      return self unless remaining?
      temp = @byte_array.slice(@position, @limit)
      # if 1 remaining the replaced range should be @byte_array[0..0]
      @byte_array[0..remaining - 1] = temp
      @position = remaining
      @limit = @size - 1
      self
    end

    # get the content of the byteBuffer. need to call rewind before calling get.
    # return as a String
    def get
      return "" if @limit.zero?
      temp = @byte_array[@position..@limit].pack("c*")
      # next position to be read. it should be always less than or equal to size-1
      @position = [@limit + 1, @size].min
      temp
    end

    def read_next(count)
      raise "Illegal Argument" unless count > 0
      raise "Less number of elements remaining" if count > remaining
      temp = @byte_array[@position..@position + count - 1].pack("c*")
      @position += count
      temp
    end

    # return the offset of the buffer
    def offset?
      @offset
    end

    # check whether the obj is the same bytebuffer as this bytebuffer
    def equals?(obj)
      self == obj
    end

    # returns the capacity of the buffer. This value is fixed to the initial size
    def capacity
      @size
    end

    # Set the position to a different position
    def position(new_position)
      raise "Illegal Argument Exception" unless new_position <= @limit && new_position >= 0
      @position = new_position
      @mark = -1 if @mark > @position
    end

    def limit(new_limit)
      raise "Illegal Argument Exception" if new_limit > @size || new_limit < 0
      @limit = new_limit
      @position = @limit if @position > @limit
      @mark = -1 if @mark > @limit
    end

    def limit?
      @limit
    end

    def to_s
      # convert String in byte form to the visible string
      temp = "ByteBuffer "
      temp += "[pos=" + @position.to_s
      temp += " lim =" + @limit.to_s
      temp += " cap=" + @size.to_s
      temp += "]"
      temp
    end

    private

    def put_byte(byte)
      raise "Buffer Overflowed" if @position == @size
      @byte_array[@position] = byte
      @position += 1
    end
  end
end
