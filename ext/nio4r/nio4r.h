/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#ifndef NIO4R_H
#define NIO4R_H

#include "ruby.h"
#include "libev.h"

struct NIO_Selector
{
    struct ev_loop *ev_loop;
    struct ev_timer timer; /* for timeouts */

    int closed;
    int ready_count;
    int ready_buffer_size;
    VALUE *ready_buffer;
};

struct NIO_callback_data
{
    VALUE *monitor;
    struct NIO_Selector *selector;
};

struct NIO_Monitor
{
    VALUE self;
    struct ev_io ev_io;
    struct NIO_Selector *selector;
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

/* Thunk between libev callbacks in NIO::Monitors and NIO::Selectors */
void NIO_Selector_handle_event(struct NIO_Selector *selector, VALUE monitor, int revents);

#endif /* NIO4R_H */
