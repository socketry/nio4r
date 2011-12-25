/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

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
static VALUE NIO_Selector_select(int argc, VALUE *argv, VALUE self);
static VALUE NIO_Selector_close(VALUE self);
static VALUE NIO_Selector_closed(VALUE self);

/* Internal functions */
static VALUE NIO_Selector_synchronize(VALUE self, VALUE (*func)(VALUE arg), VALUE arg);
static VALUE NIO_Selector_unlock(VALUE lock);
static VALUE NIO_Selector_register_synchronized(VALUE array);
static VALUE NIO_Selector_select_synchronized(VALUE array);
static VALUE NIO_Selector_run_evloop(void *ptr);
static void NIO_Selector_timeout_callback(struct ev_loop *ev_loop, struct ev_timer *timer, int revents);

/* Default number of slots in the buffer for selected monitors */
#define INITIAL_READY_BUFFER 32

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
    rb_define_method(cNIO_Selector, "select", NIO_Selector_select, -1);
    rb_define_method(cNIO_Selector, "close", NIO_Selector_close, 0);
    rb_define_method(cNIO_Selector, "closed?", NIO_Selector_closed, 0);
}

/* Create the libev event loop and incoming event buffer */
static VALUE NIO_Selector_allocate(VALUE klass)
{
    struct NIO_Selector *selector = (struct NIO_Selector *)xmalloc(sizeof(struct NIO_Selector));

    selector->ev_loop = ev_loop_new(0);
    ev_init(&selector->timer, NIO_Selector_timeout_callback);

    selector->closed = selector->ready_count = 0;
    selector->ready_buffer_size = INITIAL_READY_BUFFER;
    selector->ready_buffer = (VALUE *)xmalloc(sizeof(VALUE) * INITIAL_READY_BUFFER);

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

    xfree(selector->ready_buffer);
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

/* Register an IO object with the selector for the given interests */
static VALUE NIO_Selector_register(VALUE self, VALUE io, VALUE interests)
{
    VALUE array = rb_ary_new3(3, self, io, interests);
    return NIO_Selector_synchronize(self, NIO_Selector_register_synchronized, array);
}

/* Internal implementation of register after acquiring mutex */
static VALUE NIO_Selector_register_synchronized(VALUE array)
{
    VALUE self, io, interests, selectables, monitor;
    VALUE args[3];

    /* FIXME: Meh, these should probably be varargs */
    self = rb_ary_entry(array, 0);
    io = rb_ary_entry(array, 1);
    interests = rb_ary_entry(array, 2);

    selectables = rb_ivar_get(self, rb_intern("selectables"));
    monitor = rb_hash_lookup(selectables, io);

    if(monitor != Qnil)
        rb_raise(rb_eRuntimeError, "this IO is already registered with selector");

    /* Create a new NIO::Monitor */
    args[0] = self;
    args[1] = io;
    args[2] = interests;

    monitor = rb_class_new_instance(3, args, cNIO_Monitor);
    rb_hash_aset(selectables, io, monitor);

    return monitor;
}

/* Select from all registered IO objects */
static VALUE NIO_Selector_select(int argc, VALUE *argv, VALUE self)
{
    VALUE timeout, array;

    rb_scan_args(argc, argv, "01", &timeout);
    array = rb_ary_new3(2, self, timeout);

    return NIO_Selector_synchronize(self, NIO_Selector_select_synchronized, array);
}

/* Internal implementation of select with the selector lock held */
static VALUE NIO_Selector_select_synchronized(VALUE array)
{
    VALUE self, timeout, result;
    struct NIO_Selector *selector;

    /* FIXME: Meh, these should probably be varargs */
    self = rb_ary_entry(array, 0);
    timeout = rb_ary_entry(array, 1);

    Data_Get_Struct(self, struct NIO_Selector, selector);

    if(timeout != Qnil) {
        selector->timer.repeat = NUM2DBL(timeout);
        ev_timer_again(selector->ev_loop, &selector->timer);
    } else {
        ev_timer_stop(selector->ev_loop, &selector->timer);
    }

#if defined(HAVE_RB_THREAD_BLOCKING_REGION)
    /* Ruby 1.9 lets us release the GIL and make a blocking I/O call */
    rb_thread_blocking_region(NIO_Selector_run_evloop, selector, RUBY_UBF_IO, 0);
#else
    /* FIXME:
    This makes a blocking call in 1.8 which will hang the entire
    interpreter and prevent threads from being scheduled. I honestly don't
    care about 1.8 that much. Let me know if you do and I can investigate
    doing similar green thread workarounds as EM and cool.io */

    TRAP_BEG;
    NIO_Selector_run_evloop(selector);
    TRAP_END;
#endif

    result = rb_ary_new4(selector->ready_count, selector->ready_buffer);
    selector->ready_count = 0;

    return result;
}

/* Run the libev event loop */
static VALUE NIO_Selector_run_evloop(void *ptr)
{
    struct NIO_Selector *selector = (struct NIO_Selector *)ptr;

    ev_loop(selector->ev_loop, EVLOOP_ONESHOT);

    return Qnil;
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

/* Called whenever a timeout fires on the event loop */
static void NIO_Selector_timeout_callback(struct ev_loop *ev_loop, struct ev_timer *timer, int revents)
{
    /* We don't actually need to do anything here, the mere firing of the
       timer is sufficient to interrupt the selector. However, libev still wants a callback */
}

/* This gets called from individual monitors. We must be careful here because
   the GIL isn't held, so we must rely only on standard C and can't touch
   anything Ruby-related */
void NIO_Selector_handle_event(struct NIO_Selector *selector, VALUE monitor, int revents)
{
    /* Grow the ready buffer if it's too small */
    if(selector->ready_count >= selector->ready_buffer_size) {
      selector->ready_buffer_size *= 2;
      selector->ready_buffer = (VALUE *)xrealloc(selector->ready_buffer, sizeof(VALUE) * selector->ready_buffer_size);
    }

    selector->ready_buffer[selector->ready_count] = monitor;
    selector->ready_count++;
}
