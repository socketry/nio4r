require 'mkmf'

if have_func('rb_thread_blocking_region')
  $defs << '-DHAVE_RB_THREAD_BLOCKING_REGION'
end

if have_header('sys/select.h')
  $defs << '-DEV_USE_SELECT'
end

if have_header('poll.h')
  $defs << '-DEV_USE_POLL'
end

if have_header('sys/epoll.h')
  $defs << '-DEV_USE_EPOLL'
end

if have_header('sys/event.h') and have_header('sys/queue.h')
  $defs << '-DEV_USE_KQUEUE'
end

if have_header('port.h')
  $defs << '-DEV_USE_PORT'
end

if have_header('sys/resource.h')
  $defs << '-DHAVE_SYS_RESOURCE_H'
end

dir_config 'nio4r_ext'
create_makefile 'nio4r_ext'

# win32 needs to link in "just the right order" for some reason or ioctlsocket will be mapped to an [inverted] ruby specific version.
# See libev mailing list for (not so helpful discussion--true cause I'm not sure, but this overcomes the symptom)
if RUBY_PLATFORM =~ /mingw|win32/
  makefile_contents = File.read 'Makefile'

  # "Init_cool could not be found" when loading cool.io.so.
  makefile_contents.gsub! 'DLDFLAGS = ', 'DLDFLAGS = -export-all '

  makefile_contents.gsub! 'LIBS = $(LIBRUBYARG_SHARED)', 'LIBS = -lws2_32 $(LIBRUBYARG_SHARED)'
  File.open('Makefile', 'w') { |f| f.write makefile_contents }
end