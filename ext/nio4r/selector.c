/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "nio4r.h"
#include "rubysig.h"
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>

static VALUE mNIO                = Qnil;
static VALUE cNIO_Selector       = Qnil;
static VALUE mNIO_Libev          = Qnil;
static VALUE mNIO_Libev_Selector = Qnil;

/* Allocator/deallocator */
static VALUE NIO_Selector_allocate(VALUE klass);
static void NIO_Selector_mark(struct NIO_Selector *loop);
static void NIO_Selector_shutdown(struct NIO_Selector *selector);
static void NIO_Selector_free(struct NIO_Selector *loop);

/* Methods */
static VALUE NIO_Libev_Selector_select(VALUE self, VALUE timeout);
static VALUE NIO_Libev_Selector_register(VALUE self, VALUE monitor);
static VALUE NIO_Libev_Selector_reregister(VALUE self, VALUE monitor);
static VALUE NIO_Libev_Selector_deregister(VALUE self, VALUE monitor);
static VALUE NIO_Libev_Selector_wakeup(VALUE self);
static VALUE NIO_Libev_Selector_close(VALUE self);
static VALUE NIO_Libev_Selector_closed(VALUE self);

/* Internal functions */
static int NIO_Selector_run(struct NIO_Selector *selector, VALUE timeout);
static void NIO_Selector_timeout_callback(struct ev_loop *ev_loop, struct ev_timer *timer, int revents);
static void NIO_Selector_wakeup_callback(struct ev_loop *ev_loop, struct ev_io *io, int revents);
static void NIO_Selector_monitor_callback(struct ev_loop *ev_loop, struct ev_io *io, int revents);

/* Convert back and forth from libev revents to Ruby Symbols */
static int interests_to_mask(VALUE interests);
static VALUE mask_to_interests(int mask);

/* Ruby 1.8 needs us to busy wait and run the green threads scheduler every 10ms */
#define BUSYWAIT_INTERVAL 0.01

/* Selectors wait for events */
void Init_NIO_Selector()
{
    mNIO = rb_define_module("NIO");
    mNIO_Libev = rb_define_module_under(mNIO, "Libev");
    cNIO_Selector = rb_const_get(mNIO, rb_intern("Selector"));
    mNIO_Libev_Selector = rb_define_module_under(mNIO_Libev, "Selector");

    rb_define_alloc_func(cNIO_Selector, NIO_Selector_allocate);

    rb_define_method(mNIO_Libev_Selector, "select", NIO_Libev_Selector_select, 1);
    rb_define_method(mNIO_Libev_Selector, "wakeup", NIO_Libev_Selector_wakeup, 0);
    rb_define_method(mNIO_Libev_Selector, "close", NIO_Libev_Selector_close, 0);
    rb_define_method(mNIO_Libev_Selector, "closed?", NIO_Libev_Selector_closed, 0);

    rb_define_method(mNIO_Libev_Selector, "register", NIO_Libev_Selector_register,   1);
    // rb_define_method(cNIO_Selector, "native_reregister", NIO_Selector_native_reregister, 1);
    rb_define_method(mNIO_Libev_Selector, "deregister", NIO_Libev_Selector_deregister, 1);
}

/* Create the libev event loop and incoming event buffer */
static VALUE NIO_Selector_allocate(VALUE klass)
{
    struct NIO_Selector *selector;
    int fds[2];

    /* Use a pipe to implement the wakeup mechanism. I know libev provides
       async watchers that implement this same behavior, but I'm getting
       segvs trying to use that between threads, despite claims of thread
       safety. Pipes are nice and safe to use between threads.

       Note that Java NIO uses this same mechanism */
    if(pipe(fds) < 0) {
        rb_sys_fail("pipe");
    }

    if(fcntl(fds[0], F_SETFL, O_NONBLOCK) < 0) {
        rb_sys_fail("fcntl");
    }

    selector = (struct NIO_Selector *)xmalloc(sizeof(struct NIO_Selector));
    selector->ev_loop = ev_loop_new(0);
    ev_init(&selector->timer, NIO_Selector_timeout_callback);

    selector->wakeup_reader = fds[0];
    selector->wakeup_writer = fds[1];

    ev_io_init(&selector->wakeup, NIO_Selector_wakeup_callback, selector->wakeup_reader, EV_READ);
    selector->wakeup.data = (void *)selector;
    ev_io_start(selector->ev_loop, &selector->wakeup);

    selector->closed = selector->selecting = selector->ready_count = 0;
    selector->ready_array = Qnil;

    return Data_Wrap_Struct(klass, NIO_Selector_mark, NIO_Selector_free, selector);
}

/* NIO selectors store all Ruby objects in instance variables so mark is a stub */
static void NIO_Selector_mark(struct NIO_Selector *selector)
{
    if(selector->ready_array != Qnil) {
        rb_gc_mark(selector->ready_array);
    }
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

    close(selector->wakeup_reader);
    close(selector->wakeup_writer);

    selector->closed = 1;
}

/* Ruby finalizer for selector objects */
static void NIO_Selector_free(struct NIO_Selector *selector)
{
    NIO_Selector_shutdown(selector);
    xfree(selector);
}

/* Internal implementation of select */
static VALUE NIO_Libev_Selector_select(VALUE self, VALUE timeout)
{
    int i, ready;
    VALUE ready_array;
    struct NIO_Selector *selector;

    Data_Get_Struct(self, struct NIO_Selector, selector);
    if(!rb_block_given_p()) {
        selector->ready_array = rb_ary_new();
    }

    ready = NIO_Selector_run(selector, timeout);
    if(ready > 0) {
        if(rb_block_given_p()) {
            return INT2NUM(ready);
        } else {
            ready_array = selector->ready_array;
            selector->ready_array = Qnil;
            return ready_array;
        }
    } else {
        selector->ready_array = Qnil;
        return Qnil;
    }
}

static int NIO_Selector_run(struct NIO_Selector *selector, VALUE timeout)
{
    int result;
    selector->selecting = 1;

#if defined(HAVE_RB_THREAD_BLOCKING_REGION) || defined(HAVE_RB_THREAD_ALONE)
    /* Implement the optional timeout (if any) as a ev_timer */
    if(timeout != Qnil) {
        /* It seems libev is not a fan of timers being zero, so fudge a little */
        selector->timer.repeat = NUM2DBL(timeout) + 0.0001;
        ev_timer_again(selector->ev_loop, &selector->timer);
    } else {
        ev_timer_stop(selector->ev_loop, &selector->timer);
    }
#else
    /* Store when we started the loop so we can calculate the timeout */
    ev_tstamp started_at = ev_now(selector->ev_loop);
#endif

#if defined(HAVE_RB_THREAD_BLOCKING_REGION)
    /* libev is patched to release the GIL when it makes its system call */
    ev_loop(selector->ev_loop, EVLOOP_ONESHOT);
#elif defined(HAVE_RB_THREAD_ALONE)
    /* If we're the only thread we can make a blocking system call */
    if(rb_thread_alone()) {
#else
    /* If we don't have rb_thread_alone() we can't block */
    if(0) {
#endif /* defined(HAVE_RB_THREAD_BLOCKING_REGION) */

#if !defined(HAVE_RB_THREAD_BLOCKING_REGION)
        TRAP_BEG;
        ev_loop(selector->ev_loop, EVLOOP_ONESHOT);
        TRAP_END;
    } else {
        /* We need to busy wait as not to stall the green thread scheduler
           Ruby 1.8: just say no! :( */
        ev_timer_init(&selector->timer, NIO_Selector_timeout_callback, BUSYWAIT_INTERVAL, BUSYWAIT_INTERVAL);
        ev_timer_start(selector->ev_loop, &selector->timer);

        /* Loop until we receive events */
        while(selector->selecting && !selector->ready_count) {
            TRAP_BEG;
            ev_loop(selector->ev_loop, EVLOOP_ONESHOT);
            TRAP_END;

            /* Run the next green thread */
            rb_thread_schedule();

            /* Break if the timeout has elapsed */
            if(timeout != Qnil && ev_now(selector->ev_loop) - started_at >= NUM2DBL(timeout))
                break;
        }

        ev_timer_stop(selector->ev_loop, &selector->timer);
    }
#endif /* defined(HAVE_RB_THREAD_BLOCKING_REGION) */

    result = selector->ready_count;
    selector->selecting = selector->ready_count = 0;

    return result;
}

/* Wake the selector up from another thread */
static VALUE NIO_Libev_Selector_wakeup(VALUE self)
{
    struct NIO_Selector *selector;
    Data_Get_Struct(self, struct NIO_Selector, selector);

    if(selector->closed) {
        rb_raise(rb_eIOError, "selector is closed");
    }

    write(selector->wakeup_writer, "\0", 1);
    return Qnil;
}

/* Close the selector and free system resources */
static VALUE NIO_Libev_Selector_close(VALUE self)
{
    struct NIO_Selector *selector;
    Data_Get_Struct(self, struct NIO_Selector, selector);

    NIO_Selector_shutdown(selector);

    return Qnil;
}

/* Is the selector closed? */
static VALUE NIO_Libev_Selector_closed(VALUE self)
{
    struct NIO_Selector *selector;
    Data_Get_Struct(self, struct NIO_Selector, selector);

    return selector->closed ? Qtrue : Qfalse;
}

/* Initializes the monitor */
static VALUE NIO_Libev_Selector_register(VALUE self, VALUE monitor) {
    struct NIO_Selector *selector;
    struct NIO_Monitor  *s_monitor;

    Data_Get_Struct(monitor, struct NIO_Monitor, s_monitor);
    Data_Get_Struct(self, struct NIO_Selector, selector);

    ev_init(&s_monitor->ev_io, NIO_Selector_monitor_callback);
    return NIO_Libev_Selector_reregister(self, monitor);
}

/* Sets/resets the interest set for an extant Monitor */
static VALUE NIO_Libev_Selector_reregister(VALUE self, VALUE monitor) {
    struct NIO_Selector *selector;
    struct NIO_Monitor  *s_monitor;
    int interests = interests_to_mask(rb_funcall(monitor, rb_intern("interests"), 0, 0));

    #if HAVE_RB_IO_T
        rb_io_t *fptr;
    #else
        OpenFile *fptr;
    #endif

    Data_Get_Struct(monitor, struct NIO_Monitor, s_monitor);
    Data_Get_Struct(self, struct NIO_Selector, selector);

    GetOpenFile(rb_convert_type(rb_funcall(monitor, rb_intern("io"), 0, 0), T_FILE, "IO", "to_io"), fptr);
    
    if(ev_is_active(&s_monitor->ev_io)) {
        ev_io_stop(selector->ev_loop, &s_monitor->ev_io);
    }
    ev_io_set(&s_monitor->ev_io, FPTR_TO_FD(fptr), interests);

    //ev_io.data will always be Qnil or a pointer to the enclosing monitor object
    s_monitor->ev_io.data = (void *)monitor;
    ev_io_start(selector->ev_loop, &s_monitor->ev_io);

    return monitor;
}

static VALUE NIO_Libev_Selector_deregister(VALUE self, VALUE monitor) {
    struct NIO_Selector *selector;
    struct NIO_Monitor  *s_monitor;

    Data_Get_Struct(monitor, struct NIO_Monitor, s_monitor);
    Data_Get_Struct(self, struct NIO_Selector, selector);

    ev_io_stop(selector->ev_loop, &s_monitor->ev_io);
    return monitor;
}

/* Called whenever a timeout fires on the event loop */
static void NIO_Selector_timeout_callback(struct ev_loop *ev_loop, struct ev_timer *timer, int revents)
{
    /* We don't actually need to do anything here, the mere firing of the
       timer is sufficient to interrupt the selector. However, libev still wants a callback */
}

/* Called whenever a wakeup request is sent to a selector */
static void NIO_Selector_wakeup_callback(struct ev_loop *ev_loop, struct ev_io *io, int revents)
{
    char buffer[128];
    struct NIO_Selector *selector = (struct NIO_Selector *)io->data;
    selector->selecting = 0;

    /* Drain the wakeup pipe, giving us level-triggered behavior */
    while(read(selector->wakeup_reader, buffer, 128) > 0);
}

/* libev callback fired whenever a monitor gets an event */
static void NIO_Selector_monitor_callback(struct ev_loop *ev_loop, struct ev_io *io, int revents)
{
    VALUE monitor = (VALUE)io->data;
    VALUE selector = rb_funcall(monitor, rb_intern("selector"), 0);
    
    // struct NIO_Monitor *monitor_data = (struct NIO_Monitor *)io->data;
    struct NIO_Selector *s_selector;
    Data_Get_Struct(selector, struct NIO_Selector, s_selector);

    assert(selector != 0);
    s_selector->ready_count++;
    rb_funcall(monitor, rb_intern("readiness="), 1, mask_to_interests(revents));

    if(rb_block_given_p()) {
        rb_yield(monitor);
    } else {
        assert(s_selector->ready_array != Qnil);
        rb_ary_push(s_selector->ready_array, monitor);
    }
}

/* Converts the interests Symbol into appropriate libev mask */
static int interests_to_mask(VALUE interests)
{
    ID interests_id = SYM2ID(interests);
    
    if(interests_id == rb_intern("r")) {
        return EV_READ;
    } else if(interests_id == rb_intern("w")) {
        return EV_WRITE;
    } else if(interests_id == rb_intern("rw")) {
        return EV_READ | EV_WRITE;
    } else {
        rb_raise(rb_eArgError, "invalid event type %s (must be :r, :w, or :rw)",
            RSTRING_PTR(rb_funcall(interests, rb_intern("inspect"), 0, 0)));
    }
}

static VALUE mask_to_interests(int mask)
{
    if((mask & (EV_READ | EV_WRITE)) == (EV_READ | EV_WRITE)) {
        return ID2SYM(rb_intern("rw"));
    } else if(mask & EV_READ) {
        return ID2SYM(rb_intern("r"));
    } else if(mask & EV_WRITE) {
        return ID2SYM(rb_intern("w"));
    } else {
        return Qnil;
    }
}
