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
  end

  it "can be created with a different node size" do
    IO::Buffer.new(16384)
  end

  it "cannot set invalid node sizes" do
    proc {
      IO::Buffer.default_node_size = 0xffffffffffffffff
    }.should raise_error(RangeError)
    proc {
      IO::Buffer.default_node_size = 0
    }.should raise_error(ArgumentError)
    proc {
      IO::Buffer.new(0xffffffffffffffff)
    }.should raise_error(RangeError)
    proc {
      IO::Buffer.new(0)
    }.should raise_error(ArgumentError)
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
