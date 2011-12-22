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
    int selecting;
    int total_selected;
    int buffer_size;
    struct NIO_Selected *selected_buffer;
};

#endif
