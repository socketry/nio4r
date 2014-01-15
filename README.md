![nio4r](https://raw.github.com/celluloid/nio4r/master/logo.png)
===============
[![Gem Version](https://badge.fury.io/rb/nio4r.png)](http://rubygems.org/gems/nio4r)
[![Build Status](https://secure.travis-ci.org/celluloid/nio4r.png?branch=master)](http://travis-ci.org/celluloid/nio4r)
[![Code Climate](https://codeclimate.com/github/celluloid/nio4r.png)](https://codeclimate.com/github/celluloid/nio4r)
[![Coverage Status](https://coveralls.io/repos/celluloid/nio4r/badge.png?branch=master)](https://coveralls.io/r/celluloid/nio4r)

nio4r: New IO for Ruby.

nio4r provides an abstract, cross-platform stateful I/O selector API for Ruby.
I/O selectors are the heart of "reactor"-based event loops, and monitor
multiple I/O objects for various types of readiness, e.g. ready for reading or
writing.

The most similar API provided by Ruby today is Kernel.select, however the
select API requires you to pass in arrays of all of the I/O objects you're
interested in every time. nio4r provides a more object-oriented API that lets
you register I/O objects with a selector then handle them when they're selected
for various types of events.

nio4r is modeled after the Java NIO API, but simplified for ease-of-use.

Its goals are:

* Expose high-level interfaces for stateful IO selectors
* Keep the API small to maximize both portability and performance across many
  different OSes and Ruby VMs
* Provide inherently thread-safe facilities for working with IO objects

[Celluloid::IO](https://github.com/celluloid/celluloid-io) uses nio4r to
monitor multiple IO objects from a single Celluloid actor.

Supported Platforms
-------------------

nio4r is known to work on the following Ruby implementations:

* MRI/YARV 1.9.3, 2.0.0, 2.1.0
* JRuby 1.7.x
* Rubinius 2.x
* A pure Ruby implementation based on Kernel.select is also provided

Platform notes:

* MRI/YARV and Rubinius implement nio4r with a C extension based on libev,
  which provides a high performance binding to native IO APIs
* JRuby uses a Java extension based on the high performance Java NIO subsystem
* A pure Ruby implementation is also provided for Ruby implementations which
  don't implement the MRI C extension API

Usage
-----

### Selectors

The NIO::Selector class is the main API provided by nio4r. Use it where you
might otherwise use Kernel.select, but want to monitor the same set of IO
objects across multiple select calls rather than having to reregister them
every single time:

```ruby
require 'nio'

selector = NIO::Selector.new
```

To monitor IO objects, attach them to the selector with the NIO::Selector#register
method, monitoring them for read readiness with the :r parameter, write
readiness with the :w parameter, or both with :rw.

```ruby
>> reader, writer = IO.pipe
 => [#<IO:0xf30>, #<IO:0xf34>]
>> monitor = selector.register(reader, :r)
 => #<NIO::Monitor:0xfbc>
```

After registering an IO object with the selector, you'll get a NIO::Monitor
object which you can use for managing how a particular IO object is being
monitored. Monitors will store an arbitrary value of your choice, which
provides an easy way to implement callbacks:

```ruby
>> monitor = selector.register(reader, :r)
 => #<NIO::Monitor:0xfbc>
>> monitor.value = proc { puts "Got some data: #{monitor.io.read_nonblock(4096)}" }
 => #<Proc:0x1000@(irb):4>
```

The main method of importance is NIO::Selector#select, which monitors all
registered IO objects and returns an array of monitors that are ready.

```ruby
>> writer << "Hi there!"
 => #<IO:0x103c>
>> ready = selector.select
 => [#<NIO::Monitor:0xfbc>]
>> ready.each { |m| m.value.call }
Got some data: Hi there!
 => [#<NIO::Monitor:0xfbc>]
```

By default, NIO::Selector#select will block indefinitely until one of the IO
objects being monitored becomes ready. However, you can also pass a timeout to
wait in seconds to NIO::Selector#select just like you can with Kernel.select:

```ruby
ready = selector.select(15) # Wait 15 seconds
```

If a timeout occurs, ready will be nil.

You can avoid allocating an array each time you call NIO::Selector#select by
passing a block to select. The block will be called for each ready monitor
object, with that object passed as an argument. The number of ready monitors
is returned as a Fixnum:

```ruby
>> selector.select { |m| m.value.call }
Got some data: Hi there!
 => 1
```

When you're done monitoring a particular IO object, just deregister it from
the selector:

```ruby
selector.deregister(reader)
```

### Monitors

Monitors provide methods which let you introspect on why a particular IO
object was selected. These methods are not thread safe unless you are holding
the selector lock (i.e. if you're in a block passed to #select). Only use them
if you aren't concerned with thread safety, or you're within a #select
block:

- ***#interests***: what this monitor is interested in (:r, :w, or :rw)
- ***#readiness***: what the monitored IO object is ready for according to the last select operation
- ***#readable?***: was the IO readable last time it was selected?
- ***#writable?***: was the IO writable last time it was selected?

Monitors also support a ***#value*** and ***#value=*** method for storing a
handle to an arbitrary object of your choice (e.g. a proc)

Concurrency
-----------

nio4r provides internal locking to ensure that it's safe to use from multiple
concurrent threads. Only one thread can select on a NIO::Selector at a given
time, and while a thread is selecting other threads are blocked from
registering or deregistering IO objects. Once a pending select has completed,
requests to register/unregister IO objects will be processed.

NIO::Selector#wakeup allows one thread to unblock another thread that's in the
middle of an NIO::Selector#select operation. This lets other threads that need
to communicate immediately with the selector unblock it so it can process
other events that it's not presently selecting on.

What nio4r is not
-----------------

nio4r is not a full-featured event framework like EventMachine or Cool.io.
Instead, nio4r is the sort of thing you might write a library like that on
top of. nio4r provides a minimal API such that individual Ruby implementers
may choose to produce optimized versions for their platform, without having
to maintain a large codebase.

As of the time of writing, the current implementation is (approximately):

* 200 lines of Ruby code
* 700 lines of "custom" C code (not counting libev)
* 400 lines of Java code

nio4r is also not a replacement for Kinder Gentler IO (KGIO), a set of
advanced Ruby IO APIs. At some point in the future nio4r might provide a
cross-platform implementation that uses KGIO on CRubies, and Java NIO on JRuby,
however this is not the case today.

License
-------

Copyright (c) 2014 Tony Arcieri. Distributed under the MIT License. See
LICENSE.txt for further details.

Includes libev 4.15. Copyright (C)2007-09 Marc Alexander Lehmann. Distributed
under the BSD license. See ext/libev/LICENSE for details.
