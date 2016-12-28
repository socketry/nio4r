#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_ByteBuffer = Qnil;
static VALUE cNIO_ByteBuffer_OverflowError = Qnil;
static VALUE cNIO_ByteBuffer_UnderflowError = Qnil;

/* Allocator/deallocator */
static VALUE NIO_ByteBuffer_allocate(VALUE klass);
static void NIO_ByteBuffer_gc_mark(struct NIO_ByteBuffer *byteBuffer);
static void NIO_ByteBuffer_free(struct NIO_ByteBuffer *byteBuffer);

/* Methods */
static VALUE NIO_ByteBuffer_initialize(VALUE self, VALUE capacity);
static VALUE NIO_ByteBuffer_position(VALUE self);
static VALUE NIO_ByteBuffer_limit(VALUE self);
static VALUE NIO_ByteBuffer_capacity(VALUE self);
static VALUE NIO_ByteBuffer_remaining(VALUE self);
static VALUE NIO_ByteBuffer_full(VALUE self);
static VALUE NIO_ByteBuffer_get(VALUE self, VALUE length);
static VALUE NIO_ByteBuffer_put(VALUE self, VALUE string);
static VALUE NIO_ByteBuffer_write_to(VALUE self, VALUE file);
static VALUE NIO_ByteBuffer_read_from(VALUE self, VALUE file);
static VALUE NIO_ByteBuffer_flip(VALUE self);
static VALUE NIO_ByteBuffer_rewind(VALUE self);
static VALUE NIO_ByteBuffer_reset(VALUE self);
static VALUE NIO_ByteBuffer_mark(VALUE self);
static VALUE NIO_ByteBuffer_clear(VALUE self);
static VALUE NIO_ByteBuffer_to_s(VALUE self);

void Init_NIO_ByteBuffer()
{
    mNIO = rb_define_module("NIO");
    cNIO_ByteBuffer = rb_define_class_under(mNIO, "ByteBuffer", rb_cObject);
    rb_define_alloc_func(cNIO_ByteBuffer, NIO_ByteBuffer_allocate);

    cNIO_ByteBuffer_OverflowError  = rb_define_class_under(cNIO_ByteBuffer, "OverflowError", rb_eIOError);
    cNIO_ByteBuffer_UnderflowError = rb_define_class_under(cNIO_ByteBuffer, "UnderflowError", rb_eIOError);

    rb_define_method(cNIO_ByteBuffer, "initialize", NIO_ByteBuffer_initialize, 1);
    rb_define_method(cNIO_ByteBuffer, "clear", NIO_ByteBuffer_clear, 0);
    rb_define_method(cNIO_ByteBuffer, "position", NIO_ByteBuffer_position, 0);
    rb_define_method(cNIO_ByteBuffer, "limit", NIO_ByteBuffer_limit, 0);
    rb_define_method(cNIO_ByteBuffer, "capacity", NIO_ByteBuffer_capacity, 0);
    rb_define_method(cNIO_ByteBuffer, "size", NIO_ByteBuffer_capacity, 0);
    rb_define_method(cNIO_ByteBuffer, "remaining", NIO_ByteBuffer_remaining, 0);
    rb_define_method(cNIO_ByteBuffer, "full?", NIO_ByteBuffer_full, 0);
    rb_define_method(cNIO_ByteBuffer, "get", NIO_ByteBuffer_get, 1);
    rb_define_method(cNIO_ByteBuffer, "<<", NIO_ByteBuffer_put, 1);
    rb_define_method(cNIO_ByteBuffer, "read_from", NIO_ByteBuffer_read_from, 1);
    rb_define_method(cNIO_ByteBuffer, "write_to", NIO_ByteBuffer_write_to, 1);
    rb_define_method(cNIO_ByteBuffer, "flip", NIO_ByteBuffer_flip, 0);
    rb_define_method(cNIO_ByteBuffer, "rewind", NIO_ByteBuffer_rewind, 0);
    rb_define_method(cNIO_ByteBuffer, "reset", NIO_ByteBuffer_reset, 0);
    rb_define_method(cNIO_ByteBuffer, "mark", NIO_ByteBuffer_mark, 0);
    rb_define_method(cNIO_ByteBuffer, "to_s", NIO_ByteBuffer_to_s, 0);
}

static VALUE NIO_ByteBuffer_allocate(VALUE klass)
{
    struct NIO_ByteBuffer *bytebuffer = (struct NIO_ByteBuffer *)xmalloc(sizeof(struct NIO_ByteBuffer));
    return Data_Wrap_Struct(klass, NIO_ByteBuffer_gc_mark, NIO_ByteBuffer_free, bytebuffer);
}

static void NIO_ByteBuffer_gc_mark(struct NIO_ByteBuffer *buffer)
{
}

static void NIO_ByteBuffer_free(struct NIO_ByteBuffer *buffer)
{
    xfree(buffer);
}

static VALUE NIO_ByteBuffer_initialize(VALUE self, VALUE capacity)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    buffer->capacity = NUM2INT(capacity);
    buffer->buffer = xmalloc(buffer->capacity);

    NIO_ByteBuffer_clear(self);

    return self;
}

static VALUE NIO_ByteBuffer_clear(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    memset(buffer->buffer, 0, buffer->capacity);

    buffer->position = 0;
    buffer->limit = buffer->capacity;
    buffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_position(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return INT2NUM(buffer->position);
}

static VALUE NIO_ByteBuffer_limit(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return INT2NUM(buffer->limit);
}

static VALUE NIO_ByteBuffer_capacity(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return INT2NUM(buffer->capacity);
}

static VALUE NIO_ByteBuffer_remaining(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return INT2NUM(buffer->limit - buffer->position);
}

static VALUE NIO_ByteBuffer_full(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return buffer->position < buffer->limit;
}

static VALUE NIO_ByteBuffer_get(VALUE self, VALUE length)
{
    VALUE result;
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);
    int len = NUM2INT(length);

    if(len < 0) {
        rb_raise(rb_eArgError, "negative length given");
    }

    if(len > buffer->limit - buffer->position) {
        rb_raise(cNIO_ByteBuffer_UnderflowError, "not enough data in buffer");
    }

    result = rb_str_new(buffer->buffer + buffer->position, len);
    buffer->position += len;

    return result;
}

static VALUE NIO_ByteBuffer_put(VALUE self, VALUE string)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    long length = RSTRING_LEN(string);

    if(length > buffer->limit - buffer->position) {
        rb_raise(cNIO_ByteBuffer_OverflowError, "buffer is full");
    }

    memcpy(buffer->buffer + buffer->position, StringValuePtr(string), length);
    buffer->position += length;

    return self;
}

static VALUE NIO_ByteBuffer_read_from(VALUE self, VALUE io)
{
    struct NIO_ByteBuffer *buffer;
    rb_io_t *fptr;
    ssize_t nbytes, bytes_read;

    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);
    GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
    rb_io_set_nonblock(fptr);

    nbytes = buffer->limit - buffer->position;
    if(nbytes == 0) {
        rb_raise(cNIO_ByteBuffer_OverflowError, "buffer is full");
    }

    bytes_read = read(FPTR_TO_FD(fptr), buffer->buffer + buffer->position, nbytes);

    if(bytes_read < 0) {
        if(errno == EAGAIN) {
            return INT2NUM(0);
        } else {
            rb_sys_fail("write");
        }
    }

    buffer->position += bytes_read;

    return INT2NUM(bytes_read);
}

static VALUE NIO_ByteBuffer_write_to(VALUE self, VALUE io)
{
    struct NIO_ByteBuffer *buffer;
    rb_io_t *fptr;
    ssize_t nbytes, bytes_written;

    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);
    GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
    rb_io_set_nonblock(fptr);

    nbytes = buffer->limit - buffer->position;
    if(nbytes == 0) {
        rb_raise(cNIO_ByteBuffer_UnderflowError, "no data remaining in buffer");
    }

    bytes_written = write(FPTR_TO_FD(fptr), buffer->buffer + buffer->position, nbytes);

    if(bytes_written < 0) {
        if(errno == EAGAIN) {
            return INT2NUM(0);
        } else {
            rb_sys_fail("write");
        }
    }

    buffer->position += bytes_written;

    return INT2NUM(bytes_written);
}

static VALUE NIO_ByteBuffer_flip(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    buffer->limit = buffer->position;
    buffer->position = 0;
    buffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_rewind(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    buffer->position = 0;
    buffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_reset(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    if(buffer->mark < 0) {
        rb_raise(rb_eRuntimeError, "Invalid Mark Exception");
    } else {
        buffer->position = buffer->mark;
    }

    return self;
}

static VALUE NIO_ByteBuffer_mark(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    buffer->mark = buffer->position;
    return self;
}

static VALUE NIO_ByteBuffer_to_s(VALUE self)
{
    struct NIO_ByteBuffer *buffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, buffer);

    return rb_sprintf ("ByteBuffer [pos=%d lim=%d cap=%d]\n", buffer->position, buffer->limit, buffer->capacity);
}