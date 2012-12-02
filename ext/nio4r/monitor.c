/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Monitor = Qnil;

/* Allocator/deallocator */
static VALUE NIO_Monitor_allocate(VALUE klass);
static void NIO_Monitor_mark(struct NIO_Monitor *monitor);
static void NIO_Monitor_free(struct NIO_Monitor *monitor);

/* Methods */
static VALUE NIO_Monitor_initialize(VALUE self, VALUE selector, VALUE io, VALUE interests);
static VALUE NIO_Monitor_close(int argc, VALUE *argv, VALUE self);
static VALUE NIO_Monitor_is_closed(VALUE self);
static VALUE NIO_Monitor_set_interests(VALUE self, VALUE rhs);
static VALUE NIO_Monitor_interests(VALUE self);
static VALUE NIO_Monitor_is_readable(VALUE self);
static VALUE NIO_Monitor_is_writable(VALUE self);
static VALUE NIO_Monitor_readiness(VALUE self);

/* Internal functions */
static void NIO_Monitor_callback(struct ev_loop *ev_loop, struct ev_io *io, int revents);

#if HAVE_RB_IO_T
  rb_io_t *fptr;
#else
  OpenFile *fptr;
#endif

/* Monitor control how a channel is being waited for by a monitor */
void Init_NIO_Monitor()
{
    mNIO = rb_define_module("NIO");
    cNIO_Monitor = rb_define_class_under(mNIO, "Monitor", rb_cObject);
    rb_define_alloc_func(cNIO_Monitor, NIO_Monitor_allocate);
}

static VALUE NIO_Monitor_allocate(VALUE klass)
{
    struct NIO_Monitor *monitor = (struct NIO_Monitor *)xmalloc(sizeof(struct NIO_Monitor));
    monitor->ev_io.data = (void*)Qnil;

    return Data_Wrap_Struct(klass, NIO_Monitor_mark, NIO_Monitor_free, monitor);
}

static void NIO_Monitor_mark(struct NIO_Monitor *monitor)
{
    if((VALUE)(monitor->ev_io.data) != Qnil) {
        rb_gc_mark((VALUE)monitor->ev_io.data);
    }
}

static void NIO_Monitor_free(struct NIO_Monitor *monitor)
{
    xfree(monitor);
}