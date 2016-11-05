module NIO
  # rubocop:disable ClassLength
  class ByteBuffer
    def initialize(value, offset = nil, length = nil)
      # value can be either STRING or INTEGER
      fail "not a valid input" if value.nil?
      @position = 0
      @mark = -1
      if value.is_a? Integer
        @size = value
        @byte_array = Array.new(value)
      elsif value.is_a? String
        @byte_array = str.bytes
        @size = @byte_array.size
      end
      @limit = @size - 1
      unless offset.nil?
        @offset = offset
        @position = offset
        unless length.nil?
          fail "Invalid Arguiments Exception" if offset + length >= value
          @limit = offset + length
        end
      end
    end

    # put the provided string to the buffer
    def <<(str)
      temp_buffer = str.bytes
      temp_buffer.each { |x| put_byte x }
    end

    # return the remaining number positions to read/ write
    def remaining
      @limit + 1 - @position
    end

    # has any space remaining
    def remaining?
      remaining > 0
    end

    # this method is private
    def put_byte(byte)
      fail "Buffer Overflowed" if @position == @size
      @byte_array[@position] = byte
      @position += 1
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
      fail "Invalid Mark Exception" if @mark < 0
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
      return "" if @limit == 0
      temp = @byte_array[@position..@limit].pack("c*")
      # next position to be read. it should be always less than or equal to size-1
      @position = [@limit + 1, @size].min
      temp
    end

    def read_next(count)
      fail "Illegal Argument" unless count > 0
      fail "Less number of elements remaining" if count > remaining
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
      fail "Illegal Argument Exception" unless new_position <= @limit && new_position >= 0
      @position = new_position
      @mark = -1 if @mark > @position
    end

    def limit(new_limit)
      fail "Illegal Argument Exception" if new_limit > @size || new_limit < 0
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

    private :put_byte
  end
end
