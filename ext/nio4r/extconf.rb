require "mkmf"

have_header("unistd.h")

if have_func("rb_thread_blocking_region")
  $defs << "-DHAVE_RB_THREAD_BLOCKING_REGION"
end

if have_func("rb_thread_call_without_gvl")
  $defs << "-DHAVE_RB_THEREAD_CALL_WITHOUT_GVL"
end

$defs << "-DEV_USE_SELECT" if have_header("sys/select.h")

$defs << "-DEV_USE_POLL" if have_header("poll.h")

$defs << "-DEV_USE_EPOLL" if have_header("sys/epoll.h")

if have_header("sys/event.h") && have_header("sys/queue.h")
  $defs << "-DEV_USE_KQUEUE"
end

$defs << "-DEV_USE_PORT" if have_header("port.h")

$defs << "-DHAVE_SYS_RESOURCE_H" if have_header("sys/resource.h")

$defs << "-DHAVE_RUBYSIG_H" if RUBY_VERSION.to_f < 1.9

dir_config "nio4r_ext"
create_makefile "nio4r_ext"

# win32 needs to link in "just the right order" for some reason or
# ioctlsocket will be mapped to an [inverted] ruby specific version.
if RUBY_PLATFORM =~ /mingw|win32/
  makefile_contents = File.read "Makefile"

  makefile_contents.gsub! "DLDFLAGS = ", "DLDFLAGS = -export-all "

  makefile_contents.gsub! "LIBS = $(LIBRUBYARG_SHARED)", "LIBS = -lws2_32 $(LIBRUBYARG_SHARED)"
  File.open("Makefile", "w") { |f| f.write makefile_contents }
end
