/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "ruby.h"
#include "libev.h"
#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Selector = Qnil;

static VALUE NIO_Selector_allocate(VALUE klass);
static void NIO_Selector_mark(struct NIO_Selector *loop);
static void NIO_Selector_free(struct NIO_Selector *loop);

/* Default number of slots in the buffer for selected monitors */
#define SELECTED_BUFFER_SIZE 32

/* Selectors wait for events */
void Init_NIO_Selector()
{
    mNIO = rb_define_module("NIO");
    cNIO_Selector = rb_define_class_under(mNIO, "Selector", rb_cObject);
    rb_define_alloc_func(cNIO_Selector, NIO_Selector_allocate);
}

static VALUE NIO_Selector_allocate(VALUE klass)
{
  struct NIO_Selector *selector = (struct NIO_Selector *)xmalloc(sizeof(struct NIO_Selector));

  selector->ev_loop = 0;
  selector->selecting = selector->total_selected = 0;
  selector->buffer_size = SELECTED_BUFFER_SIZE;
  selector->selected_buffer = (struct NIO_Selected *)xmalloc(sizeof(struct NIO_Selected) * SELECTED_BUFFER_SIZE);

  return Data_Wrap_Struct(klass, NIO_Selector_mark, NIO_Selector_free, selector);
}

static void NIO_Selector_mark(struct NIO_Selector *selector)
{
}

static void NIO_Selector_free(struct NIO_Selector *selector)
{
  if(selector->ev_loop)
      ev_loop_destroy(selector->ev_loop);

  xfree(selector->selected_buffer);
  xfree(selector);
}