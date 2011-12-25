/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "ruby.h"
#include "libev.h"
#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Monitor = Qnil;

/* Allocator/deallocator */
static VALUE NIO_Monitor_allocate(VALUE klass);
static void NIO_Monitor_mark(struct NIO_Monitor *monitor);
static void NIO_Monitor_free(struct NIO_Monitor *monitor);

/* Methods */
static VALUE NIO_Monitor_initialize(VALUE self, VALUE io, VALUE interests);
static VALUE NIO_Monitor_io(VALUE self);
static VALUE NIO_Monitor_interests(VALUE self);

/* Monitor control how a channel is being waited for by a monitor */
void Init_NIO_Monitor()
{
    mNIO = rb_define_module("NIO");
    cNIO_Monitor = rb_define_class_under(mNIO, "Monitor", rb_cObject);
    rb_define_alloc_func(cNIO_Monitor, NIO_Monitor_allocate);

    rb_define_method(cNIO_Monitor, "initialize", NIO_Monitor_initialize, 2);
    rb_define_method(cNIO_Monitor, "io", NIO_Monitor_io, 0);
    rb_define_method(cNIO_Monitor, "interests", NIO_Monitor_interests, 0);
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

static VALUE NIO_Monitor_initialize(VALUE self, VALUE io, VALUE interests)
{
    rb_ivar_set(self, rb_intern("io"), io);
    rb_ivar_set(self, rb_intern("interests"), interests);

    return Qnil;
}

static VALUE NIO_Monitor_io(VALUE self)
{
    return rb_ivar_get(self, rb_intern("io"));
}

static VALUE NIO_Monitor_interests(VALUE self)
{
    return rb_ivar_get(self, rb_intern("interests"));
}
