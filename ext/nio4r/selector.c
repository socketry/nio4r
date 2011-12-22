/*
 * Copyright (c) 2011 Tony Arcieri. Distributed under the MIT License. See
 * LICENSE.txt for further details.
 */

#include "ruby.h"
#include "libev.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_Selector = Qnil;

/* Selectors wait for events */
void Init_NIO_Selector()
{
    mNIO = rb_define_module("NIO");
    cNIO_Selector = rb_define_class_under(mNIO, "Selector", rb_cObject);
}
