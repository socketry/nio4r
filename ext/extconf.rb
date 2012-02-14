require 'mkmf'

dir_config("iobuffer")
have_library("c", "main")
if have_macro("HAVE_RB_IO_T", "rubyio.h")
  have_struct_member("rb_io_t", "fd", "rubyio.h")
end

create_makefile("iobuffer_ext")
