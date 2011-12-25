/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "ruby.h"
#include "libev.h"
#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Channel  = Qnil;
static VALUE cNIO_Monitor  = Qnil;
static VALUE cNIO_Selector = Qnil;

/* Allocator/deallocator */
static VALUE NIO_Selector_allocate(VALUE klass);
static void NIO_Selector_mark(struct NIO_Selector *loop);
static void NIO_Selector_shutdown(struct NIO_Selector *selector);
static void NIO_Selector_free(struct NIO_Selector *loop);

/* Methods */
static VALUE NIO_Selector_initialize(VALUE self);
static VALUE NIO_Selector_register(VALUE self, VALUE selectable, VALUE interest);
static VALUE NIO_Selector_close(VALUE self);
static VALUE NIO_Selector_closed(VALUE self);

/* Internal functions */
static VALUE NIO_Selector_synchronize(VALUE self, VALUE (*func)(VALUE arg), VALUE arg);
static VALUE NIO_Selector_unlock(VALUE lock);
static VALUE NIO_Selector_register_synchronized(VALUE array);

/* Default number of slots in the buffer for selected monitors */
#define SELECTED_BUFFER_SIZE 32

/* Selectors wait for events */
void Init_NIO_Selector()
{
    mNIO = rb_define_module("NIO");
    cNIO_Channel  = rb_define_class_under(mNIO, "Channel",  rb_cObject);
    cNIO_Monitor  = rb_define_class_under(mNIO, "Monitor",  rb_cObject);
    cNIO_Selector = rb_define_class_under(mNIO, "Selector", rb_cObject);
    rb_define_alloc_func(cNIO_Selector, NIO_Selector_allocate);

    rb_define_method(cNIO_Selector, "initialize", NIO_Selector_initialize, 0);
    rb_define_method(cNIO_Selector, "register", NIO_Selector_register, 2);
    rb_define_method(cNIO_Selector, "close", NIO_Selector_close, 0);
    rb_define_method(cNIO_Selector, "closed?", NIO_Selector_closed, 0);
}

/* Create the libev event loop and incoming event buffer */
static VALUE NIO_Selector_allocate(VALUE klass)
{
    struct NIO_Selector *selector = (struct NIO_Selector *)xmalloc(sizeof(struct NIO_Selector));

    selector->ev_loop = ev_loop_new(0);
    selector->closed = selector->selecting = selector->total_selected = 0;
    selector->buffer_size = SELECTED_BUFFER_SIZE;
    selector->selected_buffer = (struct NIO_Selected *)xmalloc(sizeof(struct NIO_Selected) * SELECTED_BUFFER_SIZE);

    return Data_Wrap_Struct(klass, NIO_Selector_mark, NIO_Selector_free, selector);
}

/* NIO selectors store all Ruby objects in instance variables so mark is a stub */
static void NIO_Selector_mark(struct NIO_Selector *selector)
{
}

/* Free a Selector's system resources.
   Called by both NIO::Selector#close and the finalizer below */
static void NIO_Selector_shutdown(struct NIO_Selector *selector)
{
    if(selector->ev_loop) {
        ev_loop_destroy(selector->ev_loop);
        selector->ev_loop = 0;
    }

    if(selector->closed) {
        return;
    }

    selector->closed = 1;
}

/* Ruby finalizer for selector objects */
static void NIO_Selector_free(struct NIO_Selector *selector)
{
    NIO_Selector_shutdown(selector);

    xfree(selector->selected_buffer);
    xfree(selector);
}

/* Create a new selector. This is more or less the pure Ruby version
   translated into an MRI cext */
static VALUE NIO_Selector_initialize(VALUE self)
{
    VALUE lock;

    rb_ivar_set(self, rb_intern("selectables"), rb_hash_new());

    lock = rb_class_new_instance(0, 0, rb_const_get(rb_cObject, rb_intern("Mutex")));
    rb_ivar_set(self, rb_intern("lock"), lock);

    return Qnil;
}

/* Register an IO object with the selector for the given interests */
static VALUE NIO_Selector_register(VALUE self, VALUE io, VALUE interests)
{
    VALUE array = rb_ary_new3(3, self, io, interests);
    return NIO_Selector_synchronize(self, NIO_Selector_register_synchronized, array);
}

static VALUE NIO_Selector_synchronize(VALUE self, VALUE (*func)(VALUE arg), VALUE arg)
{
    VALUE lock;

    lock = rb_ivar_get(self, rb_intern("lock"));
    rb_funcall(lock, rb_intern("lock"), 0, 0);
    return rb_ensure(func, arg, NIO_Selector_unlock, lock);
}

static VALUE NIO_Selector_unlock(VALUE lock)
{
    rb_funcall(lock, rb_intern("unlock"), 0, 0);
}

static VALUE NIO_Selector_register_synchronized(VALUE array)
{
    VALUE self, io, interests, selectables, monitor;
    VALUE args[2];

    self = rb_ary_entry(array, 0);
    io = rb_ary_entry(array, 1);
    interests = rb_ary_entry(array, 2);

    selectables = rb_ivar_get(self, rb_intern("selectables"));
    monitor = rb_hash_lookup(selectables, io);

    if(monitor != Qnil)
        rb_raise(rb_eRuntimeError, "this IO is already registered with selector");

    /* Create a new NIO::Monitor */
    args[0] = io;
    args[1] = interests;

    monitor = rb_class_new_instance(2, args, cNIO_Monitor);
    rb_hash_aset(selectables, io, monitor);

    return monitor;
}

static VALUE NIO_Selector_close(VALUE self)
{
    struct NIO_Selector *selector;
    Data_Get_Struct(self, struct NIO_Selector, selector);

    NIO_Selector_shutdown(selector);

    return Qnil;
}

static VALUE NIO_Selector_closed(VALUE self)
{
    struct NIO_Selector *selector;
    Data_Get_Struct(self, struct NIO_Selector, selector);

    return selector->closed ? Qtrue : Qfalse;
}
