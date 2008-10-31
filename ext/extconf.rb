require 'mkmf'

dir_config("bytequeue")
have_library("c", "main")

create_makefile("iobuffer")
