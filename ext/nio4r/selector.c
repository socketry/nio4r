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

static VALUE NIO_Selector_allocate(VALUE klass);
static void NIO_Selector_mark(struct NIO_Selector *loop);
static void NIO_Selector_shutdown(struct NIO_Selector *selector);
static void NIO_Selector_free(struct NIO_Selector *loop);

static VALUE NIO_Selector_initialize(VALUE self);
static VALUE NIO_Selector_register(VALUE self, VALUE selectable, VALUE interest);
static VALUE NIO_Selector_add_channel(VALUE array);
static VALUE NIO_Selector_close(VALUE self);
static VALUE NIO_Selector_closed(VALUE self);

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

static VALUE NIO_Selector_allocate(VALUE klass)
{
    struct NIO_Selector *selector = (struct NIO_Selector *)xmalloc(sizeof(struct NIO_Selector));

    selector->ev_loop = ev_loop_new(0);
    selector->closed = selector->selecting = selector->total_selected = 0;
    selector->buffer_size = SELECTED_BUFFER_SIZE;
    selector->selected_buffer = (struct NIO_Selected *)xmalloc(sizeof(struct NIO_Selected) * SELECTED_BUFFER_SIZE);

    return Data_Wrap_Struct(klass, NIO_Selector_mark, NIO_Selector_free, selector);
}

static void NIO_Selector_mark(struct NIO_Selector *selector)
{
}

static void NIO_Selector_shutdown(struct NIO_Selector *selector)
{
    if(selector->ev_loop) {
        ev_loop_destroy(selector->ev_loop);
        selector->ev_loop = 0;
    }

    if(selector->closed)
        return;

    selector->closed = 1;
}

static void NIO_Selector_free(struct NIO_Selector *selector)
{
    NIO_Selector_shutdown(selector);

    xfree(selector->selected_buffer);
    xfree(selector);
}

static VALUE NIO_Selector_initialize(VALUE self)
{
    VALUE lock;

    rb_ivar_set(self, rb_intern("selectables"), rb_hash_new());

    lock = rb_class_new_instance(0, 0, rb_const_get(rb_cObject, rb_intern("Mutex")));
    rb_ivar_set(self, rb_intern("lock"), lock);

    return Qnil;
}

static VALUE NIO_Selector_register(VALUE self, VALUE selectable, VALUE interests)
{
    VALUE channel, lock, array;

    if(rb_obj_is_kind_of(selectable, cNIO_Channel))
        channel = selectable;
    else
        channel = rb_funcall(selectable, rb_intern("channel"), 0, 0);

    rb_funcall(channel, rb_intern("blocking="), 1, Qfalse);

    lock = rb_ivar_get(self, rb_intern("lock"));
    array = rb_ary_new3(3, self, channel, interests);

    /* FIXME: Blah! This is from intern.h and doesn't work on rbx :( */
    return rb_mutex_synchronize(lock, NIO_Selector_add_channel, array);
}

static VALUE NIO_Selector_add_channel(VALUE array)
{
    VALUE self, channel, interests, selectables, monitor;
    VALUE args[2];

    self = rb_ary_entry(array, 0);
    channel = rb_ary_entry(array, 1);
    interests = rb_ary_entry(array, 3);

    selectables = rb_ivar_get(self, rb_intern("selectables"));
    monitor = rb_hash_lookup(selectables, channel);

    if(monitor != Qnil)
        rb_raise(rb_eRuntimeError, "already registered");

    /* Create a new NIO::Monitor */
    args[0] = channel;
    args[1] = interests;

    monitor = rb_class_new_instance(2, args, cNIO_Monitor);
    rb_hash_aset(selectables, channel, monitor);

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
