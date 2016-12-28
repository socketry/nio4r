package org.nio4r;

import java.io.IOException;
import java.nio.channels.Channel;
import java.nio.channels.SelectableChannel;
import java.nio.channels.ReadableByteChannel;
import java.nio.channels.WritableByteChannel;
import java.nio.BufferOverflowException;
import java.nio.BufferUnderflowException;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyIO;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/*
created by Upekshej
 */
public class ByteBuffer extends RubyObject {
    private java.nio.ByteBuffer byteBuffer;

    public static RaiseException newOverflowError(ThreadContext context, String message) {
        RubyClass klass = context.runtime.getModule("NIO").getClass("ByteBuffer").getClass("OverflowError");
        return context.runtime.newRaiseException(klass, message);
    }

    public static RaiseException newUnderflowError(ThreadContext context, String message) {
        RubyClass klass = context.runtime.getModule("NIO").getClass("ByteBuffer").getClass("UnderflowError");
        return context.runtime.newRaiseException(klass, message);
    }

    public ByteBuffer(final Ruby ruby, RubyClass rubyClass) {
        super(ruby, rubyClass);
    }

    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject capacity) {
        this.byteBuffer = java.nio.ByteBuffer.allocate(RubyNumeric.num2int(capacity));
        return this;
    }

    @JRubyMethod
    public IRubyObject clear(ThreadContext context) {
        this.byteBuffer.clear();
        return this;
    }

    @JRubyMethod
    public IRubyObject position(ThreadContext context) {
        return context.getRuntime().newFixnum(this.byteBuffer.position());
    }

    @JRubyMethod
    public IRubyObject limit(ThreadContext context) {
        return context.getRuntime().newFixnum(this.byteBuffer.limit());
    }

    @JRubyMethod(name = {"capacity", "size"})
    public IRubyObject capacity(ThreadContext context) {
        return context.getRuntime().newFixnum(this.byteBuffer.capacity());
    }

    @JRubyMethod
    public IRubyObject remaining(ThreadContext context) {
        return context.getRuntime().newFixnum(this.byteBuffer.remaining());
    }

    @JRubyMethod(name = "full?")
    public IRubyObject isFull(ThreadContext context) {
        if (this.byteBuffer.hasRemaining()) {
            return context.getRuntime().getFalse();
        } else {
            return context.getRuntime().getTrue();
        }
    }

    @JRubyMethod
    public IRubyObject get(ThreadContext context, IRubyObject length) {
        int len = RubyNumeric.num2int(length);
        byte[] bytes = new byte[len];

        try {
            this.byteBuffer.get(bytes);
        } catch(BufferUnderflowException e) {
            throw ByteBuffer.newUnderflowError(context, "not enough data in buffer");
        }

        return RubyString.newString(context.getRuntime(), bytes);
    }

    @JRubyMethod(name = "<<")
    public IRubyObject put(ThreadContext context, IRubyObject str) {
        String string = str.asJavaString();

        try {
            this.byteBuffer.put(string.getBytes());
        } catch(BufferOverflowException e) {
            throw ByteBuffer.newOverflowError(context, "buffer is full");
        }

        return this;
    }

    @JRubyMethod(name = "read_from")
    public IRubyObject readFrom(ThreadContext context, IRubyObject io) {
        Ruby runtime = context.runtime;
        Channel channel = RubyIO.convertToIO(context, io).getChannel();

        if(!this.byteBuffer.hasRemaining()) {
            throw ByteBuffer.newOverflowError(context, "buffer is full");
        }
        
        if(!(channel instanceof ReadableByteChannel) || !(channel instanceof SelectableChannel)) {
            throw runtime.newArgumentError("unsupported IO object: " + io.getType().toString());
        }

        try {
            ((SelectableChannel)channel).configureBlocking(false);
        } catch(IOException ie) {
            throw runtime.newIOError(ie.getLocalizedMessage());
        }

        try {
            int bytesRead = ((ReadableByteChannel)channel).read(this.byteBuffer);

            if(bytesRead >= 0) {
                return runtime.newFixnum(bytesRead);
            } else {
                throw runtime.newEOFError();
            }
        } catch(IOException ie) {
            throw runtime.newIOError(ie.getLocalizedMessage());
        }
    }

    @JRubyMethod(name = "write_to")
    public IRubyObject writeTo(ThreadContext context, IRubyObject io) {
        Ruby runtime = context.runtime;
        Channel channel = RubyIO.convertToIO(context, io).getChannel();

        if(!this.byteBuffer.hasRemaining()) {
            throw ByteBuffer.newUnderflowError(context, "not enough data in buffer");
        }

        if(!(channel instanceof WritableByteChannel) || !(channel instanceof SelectableChannel)) {
            throw runtime.newArgumentError("unsupported IO object: " + io.getType().toString());
        }

        try {
            ((SelectableChannel)channel).configureBlocking(false);
        } catch(IOException ie) {
            throw runtime.newIOError(ie.getLocalizedMessage());
        }

        try {
            int bytesWritten = ((WritableByteChannel)channel).write(this.byteBuffer);

            if(bytesWritten >= 0) {
                return runtime.newFixnum(bytesWritten);
            } else {
                throw runtime.newEOFError();
            }
        } catch(IOException ie) {
            throw runtime.newIOError(ie.getLocalizedMessage());
        }
    }

    @JRubyMethod
    public IRubyObject flip(ThreadContext context) {
        this.byteBuffer.flip();
        return this;
    }

    @JRubyMethod
    public IRubyObject rewind(ThreadContext context) {
        this.byteBuffer.rewind();
        return this;
    }

    @JRubyMethod
    public IRubyObject reset(ThreadContext context) {
        this.byteBuffer.reset();
        return this;
    }

    @JRubyMethod
    public IRubyObject mark(ThreadContext context) {
        this.byteBuffer.mark();
        return this;
    }

    @JRubyMethod(name = "to_s")
    public IRubyObject toString(ThreadContext context) {
        return context.runtime.newString(byteBuffer.toString());
    }
}
