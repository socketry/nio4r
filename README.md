New IO for Ruby
===============
[![Build Status](http://travis-ci.org/tarcieri/nio4r.png)](http://travis-ci.org/tarcieri/nio4r)

When it comes to doing advanced IO on Ruby, there aren't a whole lot of
options. The most powerful UI construct Ruby itself gives you is
Kernel.select, and select is hurting a bit when it comes to both performance
when selecting on large numbers of IO objects, and in terms of having a nice
API. There are a handful of new IO methods appearing in Ruby but figuring
out which one to use can be difficult.

Once upon a time Java was a similar mess. They got out of it by adding the
Java NIO API. NIO provides high level interfaces for doing operations that can
be highly optimized, such as copying a file to another file or to a socket, or
waiting on large numbers of file descriptors.

This library aims to incorporate the ideas of Java NIO in Ruby. These are:

* Expose high level interfaces for doing high performance IO
* Be as portable as possible, in this case across several Ruby VMs
* Provide inherently thread-safe facilities for working with IO objects