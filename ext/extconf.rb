require 'mkmf'

dir_config("iobuffer")
have_library("c", "main")

create_makefile("iobuffer")
