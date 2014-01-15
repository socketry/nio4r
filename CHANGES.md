1.0.0 (2014-01-14)
------------------
* Have Selector#register obtain the actual IO from a Monitor object
  because Monitor#initialize might convert it.
* Drop 1.8 support

0.5.0 (2013-08-06)
------------------
* Fix segv when attempting to register to a closed selector
* Fix Windows support on Ruby 2.0.0
* Upgrade to libev 4.15

0.4.6 (2013-05-27)
------------------
* Fix for JRuby on Windows

0.4.5
-----
* Fix botched gem release

0.4.4
-----
* Fix return values for Selector_synchronize and Selector_unlock

0.4.3
-----
* REALLY have thread synchronization when closing selectors ;)

0.4.2
-----
* Attempt to work around packaging problems with bundler-api o_O

0.4.1
-----
* Thread synchronization when closing selectors

0.4.0
-----
* OpenSSL::SSL::SSLSocket support

0.3.3
-----
* NIO::Selector#select_each removed
* Remove event buffer
* Patch GIL unlock directly into libev
* Re-release since 0.3.2 was botched :(

0.3.1
-----
* Prevent CancelledKeyExceptions on JRuby

0.3.0
-----
* NIO::Selector#select now takes a block and behaves like select_each
* NIO::Selector#select_each is now deprecated and will be removed
* Closing monitors detaches them from their selector
* Java extension for JRuby
* Upgrade to libev 4.11
* Bugfixes for zero/negative select timeouts
* Handle OP_CONNECT properly on JRuby

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
