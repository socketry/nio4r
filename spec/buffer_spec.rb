require File.expand_path(File.dirname(__FILE__) + '/../lib/iobuffer')

describe IO::Buffer do
  before :each do
    @buffer = IO::Buffer.new
    @buffer.size.should == 0
  end

  it "appends data" do
    @buffer.append "foo"
    @buffer.size.should == 3

    @buffer << "bar"
    @buffer.size.should == 6

    @buffer.write "baz"
    @buffer.size.should == 9

    @buffer.read.should == "foobarbaz"
    @buffer.size.should == 0
  end

  it "prepends data" do
    @buffer.prepend "foo"
    @buffer.size.should == 3

    @buffer.prepend "bar"
    @buffer.size.should == 6

    @buffer.read.should == "barfoo"
    @buffer.size.should == 0
  end

  it "mixes prepending and appending properly" do
    source_data = %w{foo bar baz qux}
    actions = permutator([:append, :prepend] * 2)

    actions.each do |sequence|
      sequence.each_with_index do |entry, i|
        @buffer.send(entry, source_data[i])
      end

      @buffer.size.should == sequence.size * 3

      i = 0
      expected = sequence.inject('') do |str, action|
        case action
        when :append
          str << source_data[i]
        when :prepend
          str = source_data[i] + str
        end

        i += 1
        str
      end

      @buffer.read.should == expected
    end
  end

  it "reads data in chunks properly" do
    @buffer.append "foobarbazqux"

    @buffer.read(1).should == 'f'
    @buffer.read(2).should == 'oo'
    @buffer.read(3).should == 'bar'
    @buffer.read(4).should == 'bazq'
    @buffer.read(1).should == 'u'
    @buffer.read(2).should == 'x'
  end

  it "converts to a string" do
    @buffer.append "foobar"
    @buffer.to_str == "foobar"
  end

  it "clears data" do
    @buffer.append "foo"
    @buffer.prepend "bar"

    @buffer.clear
    @buffer.size.should == 0
    @buffer.read.should == ""

    @buffer.prepend "foo"
    @buffer.prepend "bar"
    @buffer.append "baz"

    @buffer.clear
    @buffer.size.should == 0
    @buffer.read.should == ""
  end

  it "knows when it's empty" do
    @buffer.should be_empty
    @buffer.append "foo"
    @buffer.should_not be_empty
  end

  it "can set default node size" do
    IO::Buffer.default_node_size = 1
    IO::Buffer.default_node_size.should == 1
    (IO::Buffer.default_node_size = 4096).should == 4096
    (IO::Buffer.default_node_size = IO::Buffer::MAX_SIZE).should == IO::Buffer::MAX_SIZE
  end

  it "can be created with a different node size" do
    IO::Buffer.new(16384)
  end

  it "cannot set invalid node sizes" do
    proc {
      IO::Buffer.default_node_size = IO::Buffer::MAX_SIZE + 1
    }.should raise_error(ArgumentError)
    proc {
      IO::Buffer.default_node_size = 0
    }.should raise_error(ArgumentError)
    proc {
      IO::Buffer.new(IO::Buffer::MAX_SIZE + 1)
    }.should raise_error(ArgumentError)
    proc {
      IO::Buffer.new(0)
    }.should raise_error(ArgumentError)
  end

  it "Reads can read a single frame" do
    @buffer.append("foo\0bar")
    str = ""
    @buffer.read_frame(str, 0).should == true
    str.should == "foo\0"
    @buffer.size.should == 3
  end

  it "Reads a frame, then reads only some data" do
    @buffer.append("foo\0bar")
    str = ""
    @buffer.read_frame(str,0)
    str = ""
    #This will read only a partial frame
    @buffer.read_frame(str,0).should == false
    str.should == "bar"
    @buffer.size.should == 0
  end

  it "Returns nil when reading from a filehandle at EOF" do
    (rp, wp) = File.pipe

    wp.write("Foo")
    wp.flush
    @buffer.read_from(rp).should == 3
    @buffer.read_from(rp).should == 0
    wp.close
    @buffer.read_from(rp).should == nil
  end
  
  it "Maintains proper buffer size" do
    #TODO use more methods
    
    #Testing of normal append
    str = "clarp of the flarn"
    @buffer.append(str)
    s = @buffer.size
    s.should == str.length
    
    #Testing of read_from
    (rp, wp) = File.pipe
    wp.write(str)
    wp.close
    @buffer.read_from(rp)
    @buffer.size.should == 2*str.length
  end
  
  it "Can handle lots of data" do
    (rp, wp) = File.pipe
    rng = Random.new(1)
    
    total = 0
    100.times do
      chunk_size = rng.rand(2048) #We don't actually know the pipe buffer size!
      if rng.rand > 0.5
        wp.write("x" * chunk_size)
        @buffer.read_from(rp)
      else
        @buffer.append("x" * chunk_size)
      end
      total += chunk_size
    end
    wp.close
    @buffer.read_from(rp)
    
    @buffer.size.should == total
    @buffer.read.should == "x" * total
  end
  
  #######
  private
  #######

  def permutator(input)
    output = []
    return output if input.empty?

    (0..input.size - 1).inject([]) do |a, n|
      if a.empty?
        input.each { |x| output << [x] }
      else
        input.each { |x| output += a.map { |y| [x, *y] } }
      end

      output.dup
    end
  end
end
