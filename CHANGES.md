HEAD
----
* Upgrade to libev 4.11

0.2.2
-----
* Raise IOError if asked to wake up a closed selector

0.2.1
-----
* Implement wakeup mechanism using raw pipes instead of ev_async, since
  ev_async likes to cause segvs when used across threads (despite claims
  in the documentation to the contrary)

0.2.0
-----
* NIO::Monitor#readiness API to query readiness, along with #readable? and
  #writable? helper methods
* NIO::Selector#select_each API which avoids memory allocations if possible
* Bugfixes for the JRuby implementation

0.1.0
-----
* Initial release. Merry Christmas!
