/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#ifndef NIO4R_H
#define NIO4R_H

struct NIO_Selected
{
    VALUE monitor;
    int revents;
};

struct NIO_Selector
{
    struct ev_loop *ev_loop;

    int closed;
    int total_selected;
    int buffer_size;
    struct NIO_Selected *selected_buffer;
};

struct NIO_Monitor
{
    struct ev_io ev_io;
};

#ifdef GetReadFile
# define FPTR_TO_FD(fptr) (fileno(GetReadFile(fptr)))
#else

#if !HAVE_RB_IO_T || (RUBY_VERSION_MAJOR == 1 && RUBY_VERSION_MINOR == 8)
# define FPTR_TO_FD(fptr) fileno(fptr->f)
#else
# define FPTR_TO_FD(fptr) fptr->fd
#endif /* !HAVE_RB_IO_T */

#endif /* GetReadFile */

#endif /* NIO4R_H */
