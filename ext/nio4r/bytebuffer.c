#include "nio4r.h"

static VALUE mNIO = Qnil;
static VALUE cNIO_ByteBuffer = Qnil;

/* Allocator/deallocator */
static VALUE NIO_ByteBuffer_allocate(VALUE klass);
static void NIO_ByteBuffer_mark(struct NIO_ByteBuffer *byteBuffer);
static void NIO_ByteBuffer_free(struct NIO_ByteBuffer *byteBuffer);

/* Methods */
static VALUE NIO_ByteBuffer_initialize(VALUE self, VALUE capacity);
static VALUE NIO_ByteBuffer_put(VALUE self, VALUE string);
static VALUE NIO_ByteBuffer_get(VALUE self);
static VALUE NIO_ByteBuffer_readnext(VALUE self, VALUE amount);
static VALUE NIO_ByteBuffer_writeTo(VALUE self, VALUE file);
static VALUE NIO_ByteBuffer_readFrom(VALUE self, VALUE file);
static VALUE NIO_ByteBuffer_remaining(VALUE self);
static VALUE NIO_ByteBuffer_hasRemaining(VALUE self);
static VALUE NIO_ByteBuffer_getOffset(VALUE self);
static VALUE NIO_ByteBuffer_equals(VALUE self, VALUE other);
static VALUE NIO_ByteBuffer_flip(VALUE self);
static VALUE NIO_ByteBuffer_rewind(VALUE self);
static VALUE NIO_ByteBuffer_reset(VALUE self);
static VALUE NIO_ByteBuffer_markBuffer(VALUE self);
static VALUE NIO_ByteBuffer_clear(VALUE self);
static VALUE NIO_ByteBuffer_compact(VALUE self);
static VALUE NIO_ByteBuffer_capacity(VALUE self);
static VALUE NIO_ByteBuffer_position(VALUE self, VALUE newPosition);
static VALUE NIO_ByteBuffer_setLimit(VALUE self, VALUE newLimit);
static VALUE NIO_ByteBuffer_getLimit(VALUE self);
static VALUE NIO_ByteBuffer_toString(VALUE self);

void Init_NIO_ByteBuffer()
{
    mNIO = rb_define_module("NIO");
    cNIO_ByteBuffer = rb_define_class_under(mNIO, "ByteBuffer", rb_cObject);
    rb_define_alloc_func(cNIO_ByteBuffer, NIO_ByteBuffer_allocate);

    rb_define_method(cNIO_ByteBuffer, "initialize", NIO_ByteBuffer_initialize, 1);
    rb_define_method(cNIO_ByteBuffer, "<<", NIO_ByteBuffer_put, 1);
    rb_define_method(cNIO_ByteBuffer, "get", NIO_ByteBuffer_get, 0);
    rb_define_method(cNIO_ByteBuffer, "read_next", NIO_ByteBuffer_readnext, 1);
    rb_define_method(cNIO_ByteBuffer, "write_to", NIO_ByteBuffer_writeTo, 1);
    rb_define_method(cNIO_ByteBuffer, "read_from", NIO_ByteBuffer_readFrom, 1);
    rb_define_method(cNIO_ByteBuffer, "remaining", NIO_ByteBuffer_remaining, 0);
    rb_define_method(cNIO_ByteBuffer, "remaining?", NIO_ByteBuffer_hasRemaining, 0);
    rb_define_method(cNIO_ByteBuffer, "offset?", NIO_ByteBuffer_getOffset, 0);
    rb_define_method(cNIO_ByteBuffer, "equals", NIO_ByteBuffer_equals, 1);
    rb_define_method(cNIO_ByteBuffer, "flip", NIO_ByteBuffer_flip, 0);
    rb_define_method(cNIO_ByteBuffer, "rewind", NIO_ByteBuffer_rewind, 0);
    rb_define_method(cNIO_ByteBuffer, "reset", NIO_ByteBuffer_reset, 0);
    rb_define_method(cNIO_ByteBuffer, "mark", NIO_ByteBuffer_markBuffer, 0);
    rb_define_method(cNIO_ByteBuffer, "clear", NIO_ByteBuffer_clear, 0);
    rb_define_method(cNIO_ByteBuffer, "compact", NIO_ByteBuffer_compact, 0);
    rb_define_method(cNIO_ByteBuffer, "capacity", NIO_ByteBuffer_capacity, 0);
    rb_define_method(cNIO_ByteBuffer, "position", NIO_ByteBuffer_position, 1);
    rb_define_method(cNIO_ByteBuffer, "limit", NIO_ByteBuffer_setLimit, 1);
    rb_define_method(cNIO_ByteBuffer, "limit?", NIO_ByteBuffer_getLimit, 0);
    rb_define_method(cNIO_ByteBuffer, "to_s", NIO_ByteBuffer_toString, 0);
}

static VALUE NIO_ByteBuffer_allocate(VALUE klass)
{
    struct NIO_ByteBuffer *bytebuffer = (struct NIO_ByteBuffer *)xmalloc(sizeof(struct NIO_ByteBuffer));
    return Data_Wrap_Struct(klass, NIO_ByteBuffer_mark, NIO_ByteBuffer_free, bytebuffer);
}

static void NIO_ByteBuffer_mark(struct NIO_ByteBuffer *buffer)
{
}

static void NIO_ByteBuffer_free(struct NIO_ByteBuffer *buffer)
{
    xfree(buffer);
}

static VALUE NIO_ByteBuffer_initialize(VALUE self, VALUE capacity)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    byteBuffer->size = NUM2INT(capacity);
    byteBuffer->buffer = xmalloc(byteBuffer->size);
    byteBuffer->position = 0;
    byteBuffer->offset = 0;
    byteBuffer->limit = byteBuffer->size - 1;
    byteBuffer->self = self;

    return self;
}

static VALUE NIO_ByteBuffer_put(VALUE self, VALUE string)
{
    uint i;
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    char *ptr  = StringValuePtr(string);
    long length = RSTRING_LEN(string);

    for(i = 0; i < length; i++) {
        byteBuffer->buffer[byteBuffer->position] = ptr[i];
        byteBuffer->position++;
    }

    return self;
}

static VALUE NIO_ByteBuffer_get(VALUE self)
{
    uint i;
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    int remaining = NUM2INT(NIO_ByteBuffer_remaining(self));

    if(remaining == 0) {
        return rb_str_new2("");
    }

    char tempArray[remaining + 1];

    for(i = 0; byteBuffer->position <= byteBuffer->limit; i++) {
        tempArray[i] = byteBuffer->buffer[byteBuffer->position];
        byteBuffer->position++;
    }

    tempArray[remaining] = '\0';
    return rb_str_new2(tempArray);
}

static VALUE NIO_ByteBuffer_readnext(VALUE self, VALUE amount)
{
    int amnt = NUM2INT(amount);
    if(amnt < 1) {
        rb_raise(rb_eTypeError, "not a valid input");
    }

    if(amnt > NUM2INT(NIO_ByteBuffer_remaining(self))) {
        rb_raise(rb_eTypeError, "Less number of elements remaining");
    }

    char tempArray[amnt+1];
    int c = 0;
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    while(c < amnt) {
        tempArray[c++] = byteBuffer->buffer[byteBuffer->position];
        byteBuffer->position++;
    }

    tempArray[amnt] = '\0';
    return rb_str_new2(tempArray);
}

static VALUE NIO_ByteBuffer_writeTo(VALUE self, VALUE io)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);
    int size = byteBuffer->limit + 1 - byteBuffer->position;

    #if HAVE_RB_IO_T
        rb_io_t        *fptr;
    #else
        OpenFile       *fptr;
    #endif

    GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
    rb_io_set_nonblock(fptr);

    VALUE content = NIO_ByteBuffer_get(self);
    char* contentAsPointer = StringValuePtr(content);

    write(FPTR_TO_FD(fptr), contentAsPointer , size);

    return self;
}

static VALUE NIO_ByteBuffer_readFrom(VALUE self, VALUE io)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    #if HAVE_RB_IO_T
        rb_io_t        *fptr;
    #else
        OpenFile       *fptr;
    #endif

    GetOpenFile(rb_convert_type(io, T_FILE, "IO", "to_io"), fptr);
    rb_io_set_nonblock(fptr);

    while(NIO_ByteBuffer_hasRemaining(self) == Qtrue) {
        char* nextByte;
        read(FPTR_TO_FD(fptr), &nextByte, 1);
        VALUE byte = rb_str_new2(nextByte);
        NIO_ByteBuffer_put(self, byte);
    }

    return self;
}

static VALUE NIO_ByteBuffer_remaining(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    return INT2NUM(byteBuffer->limit + 1 - byteBuffer->position);
}

static VALUE NIO_ByteBuffer_hasRemaining(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    return ((byteBuffer->limit + 1 - byteBuffer->position) > 0) ? Qtrue : Qfalse;
}

static VALUE NIO_ByteBuffer_getOffset(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);
    return INT2NUM(byteBuffer->offset);
}

static VALUE NIO_ByteBuffer_equals(VALUE self, VALUE other)
{
    return self == other ? Qtrue : Qfalse;
}

static VALUE NIO_ByteBuffer_flip(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    byteBuffer->limit = (byteBuffer->position > 0) ? byteBuffer->position - 1 : 0;
    byteBuffer->position = 0;
    byteBuffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_rewind(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    byteBuffer->position = 0;
    byteBuffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_reset(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    if(byteBuffer->mark < 0){
        rb_raise(rb_eRuntimeError, "Invalid Mark Exception");
    } else {
        byteBuffer->position = byteBuffer->mark;
    }

    return self;
}

static VALUE NIO_ByteBuffer_markBuffer(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    byteBuffer->mark = byteBuffer->position;
    return self;
}

static VALUE NIO_ByteBuffer_clear(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    byteBuffer->position = 0;
    byteBuffer->limit = byteBuffer->size - 1;
    byteBuffer->mark = -1;

    return self;
}

static VALUE NIO_ByteBuffer_compact(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    if(NIO_ByteBuffer_hasRemaining(self) == Qtrue) {
        //move content
        int i = 0, j = byteBuffer->position;
        for(j = byteBuffer->position; j <= byteBuffer->limit; j++) {
            byteBuffer->buffer[i++] = byteBuffer->buffer[j];
        }

        byteBuffer->position = i;
        byteBuffer->limit = byteBuffer->size - 1;
    }

    return self;
}

static VALUE NIO_ByteBuffer_capacity(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    return INT2NUM(byteBuffer->size);
}

static VALUE NIO_ByteBuffer_position(VALUE self, VALUE newposition)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    int newPosition = NUM2INT(newposition);

    if(newPosition < 0 || newPosition > byteBuffer->limit) {
      rb_raise(rb_eRuntimeError, "Illegal Argument Exception");
    } else {
        byteBuffer->position = newPosition;

        if(byteBuffer->mark > newPosition) {
            byteBuffer->mark = -1;
        }
    }
    return self;
}

static VALUE NIO_ByteBuffer_setLimit(VALUE self, VALUE newlimit)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    int newLimit = NUM2INT(newlimit);

    if(newLimit < byteBuffer->size && newLimit >= 0)
    {
        byteBuffer->limit = newLimit;

        if(byteBuffer->position > byteBuffer->limit) {
            byteBuffer->position = newLimit;
        }

        if(byteBuffer->mark > byteBuffer->limit) {
            byteBuffer->mark  = -1;
        }
    } else {
        rb_raise(rb_eRuntimeError, "Illegal Argument Exception");
    }

    return self;
}

static VALUE NIO_ByteBuffer_getLimit(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    return INT2NUM(byteBuffer->limit);
}

static VALUE NIO_ByteBuffer_toString(VALUE self)
{
    struct NIO_ByteBuffer *byteBuffer;
    Data_Get_Struct(self, struct NIO_ByteBuffer, byteBuffer);

    return rb_sprintf ("ByteBuffer [pos=%d lim=%d cap=%d]\n", byteBuffer->position, byteBuffer->limit, byteBuffer->size);
}
