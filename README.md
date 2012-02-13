IO::Buffer
==========
[![Build Status](http://travis-ci.org/tarcieri/iobuffer.png)](http://travis-ci.org/tarcieri/iobuffer)

IO::Buffer is a fast byte queue which is primarily intended for non-blocking
I/O applications but is suitable wherever buffering is required. IO::Buffer
is compatible with Ruby 1.8/1.9 and Rubinius.

Usage
-----

IO::Buffer provides a subset of the methods available in Strings:

```ruby
>> buf = IO::Buffer.new
=> #<IO::Buffer:0x12fc708>
>> buf << "foo"
=> "foo"
>> buf << "bar"
=> "bar"
>> buf.to_str
=> "foobar"
>> buf.size
=> 6
```

The IO::Buffer#<< method is an alias for IO::Buffer#append.  A prepend method
is also available:

```ruby
>> buf = IO::Buffer.new
=> #<IO::Buffer:0x12f5250>
>> buf.append "bar"
=> "bar"
>> buf.prepend "foo"
=> "foo"
>> buf.append "baz"
=> "baz"
>> buf.to_str
=> "foobarbaz"
```

IO::Buffer#read can be used to retrieve the contents of a buffer.  You can mix
reads alongside adding more data to the buffer:

```ruby
>> buf = IO::Buffer.new
=> #<IO::Buffer:0x12fc5f0>
>> buf << "foo"
=> "foo"
>> buf.read 2
=> "fo"
>> buf << "bar"
=> "bar"
>> buf.read 2
=> "ob"
>> buf << "baz"
=> "baz"
>> buf.read 3
=> "arb"
```

Finally, IO::Buffer provides methods for performing non-blocking I/O with the
contents of the buffer.  The IO::Buffer#read_from(IO) method will read as much
data as possible from the given IO object until the read would block.

The IO::Buffer#write_to(IO) method writes the contents of the buffer to the
given IO object until either the buffer is empty or the write would block:

```ruby
>> buf = IO::Buffer.new
=> #<IO::Buffer:0x12fc5c8>
>> file = File.open("README")
=> #<File:README>
>> buf.read_from(file)
=> 1713
>> buf.to_str
=> "= IO::Buffer\n\nIO::Buffer is a fast byte queue...
```

If the file descriptor is not ready for I/O, the Errno::EAGAIN exception is
raised indicating no I/O was performed.

Contributing
------------

* Fork this repository on github
* Make your changes and send me a pull request
* If I like them I'll merge them
* If I've accepted a patch, feel free to ask for commit access

License
-------

Copyright (c) 2007-12 Tony Arcieri. Distributed under the MIT License. See
LICENSE.txt for further details.
