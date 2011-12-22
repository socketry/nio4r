/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "ruby.h"
#include "libev.h"
#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Monitor = Qnil;

static VALUE NIO_Monitor_allocate(VALUE klass);
static void NIO_Monitor_mark(struct NIO_Monitor *monitor);
static void NIO_Monitor_free(struct NIO_Monitor *monitor);

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

    return Data_Wrap_Struct(klass, NIO_Monitor_mark, NIO_Monitor_free, monitor);
}

static void NIO_Monitor_mark(struct NIO_Monitor *monitor)
{
}

static void NIO_Monitor_free(struct NIO_Monitor *monitor)
{
    xfree(monitor);
}