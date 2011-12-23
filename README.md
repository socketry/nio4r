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

* Expose high level interfaces for doing high performance IO, but keep the
  codebase small to encourage multiple implementations on different platforms
* Be as portable as possible, in this case across several Ruby VMs
* Provide inherently thread-safe facilities for working with IO objects

Supported Platforms
-------------------

nio4r is known to work on the following Ruby implementations:

* MRI/YARV 1.8.7, 1.9.2, 1.9.3
* JRuby 1.6.x (and likely earlier versions too)
* Rubinius 1.x/2.0
* A pure Ruby implementation based on Kernel.select is also provided

Platform notes:

* MRI/YARV and Rubinius implement nio4j with a C extension based on libev,
  which provides a high performance binding to native IO APIs.
* JRuby uses a special backend based on Java NIO which should have fairly good
  performance for monitoring large numbers of IO objects.
* A pure Ruby implementation is also provided for Ruby implementations which
  don't implement the MRI C extension API.

License
-------

Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
LICENSE.txt for further details.

Includes libev. Copyright (C)2007-09 Marc Alexander Lehmann. Distributed under
the BSD license. See ext/libev/LICENSE for details.
