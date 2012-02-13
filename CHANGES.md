1.1.1
-----
* Fix problems with native extension not compiling

1.1.0
-----
* IO::Buffer#read_frame for reading delimited data
* Bugfixes (#6)
* Some basic gem modernization

1.0.0
-----
* Switch to rake-compiler for building the C extension
* Define IO::Buffer::MAX_SIZE (1 GiB) as the maximum buffer size
* Raise ArgumentError instead of RangeError if the buffer size is too big

0.1.3
-----
* Fix botched release :(
* Update gemspec so it only globs .c and .rb files, to prevent future
  botched releases containing .o or .so files.

0.1.2
-----
* Tuneable node size

0.1.1
-----
* Ruby 1.8.7 compatibility fix

0.1.0
-----
* Initial release
