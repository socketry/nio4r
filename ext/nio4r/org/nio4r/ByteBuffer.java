package org.nio4r;

import org.jruby.*;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.channels.FileChannel;
import java.nio.BufferOverflowException;
import java.nio.BufferUnderflowException;
import java.util.ArrayList;

/*
created by Upekshej
 */
public class ByteBuffer extends RubyObject {
    private java.nio.ByteBuffer byteBuffer;
    private String currentWritePath = "";
    private String currentReadPath = "";

    private FileChannel currentWriteFileChannel;
    private FileOutputStream fileOutputStream;

    private FileInputStream currentReadChannel;
    private FileChannel inChannel;

    public ByteBuffer(final Ruby ruby, RubyClass rubyClass) {
        super(ruby, rubyClass);
    }

    public static RaiseException newOverflowError(ThreadContext context, String message) {
        RubyClass klass = context.runtime.getModule("NIO").getClass("ByteBuffer").getClass("OverflowError");
        return context.runtime.newRaiseException(klass, message);
    }

    public static RaiseException newUnderflowError(ThreadContext context, String message) {
        RubyClass klass = context.runtime.getModule("NIO").getClass("ByteBuffer").getClass("UnderflowError");
        return context.runtime.newRaiseException(klass, message);
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
    public IRubyObject full(ThreadContext context) {
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

    @JRubyMethod
    public IRubyObject write_to(ThreadContext context, IRubyObject f) {
        try {
            File file = (File) JavaUtil.unwrapJavaObject(f);

            if (!isTheSameFile(file, false)) {
                currentWritePath = file.getAbsolutePath();
                if (currentWriteFileChannel != null) currentWriteFileChannel.close();
                if (fileOutputStream != null) fileOutputStream.close();

                fileOutputStream = new FileOutputStream(file, true);
                currentWriteFileChannel = fileOutputStream.getChannel();
            }

            currentWriteFileChannel.write(this.byteBuffer);
        } catch (Exception e) {
            throw new IllegalArgumentException("write error: " + e.getLocalizedMessage());
        }

        return this;
    }

    @JRubyMethod
    public IRubyObject read_from(ThreadContext context, IRubyObject f) {
        try {
            File file = (File) JavaUtil.unwrapJavaObject(f);

            if (!isTheSameFile(file, true)) {
                inChannel.close();
                currentReadChannel.close();
                currentReadPath = file.getAbsolutePath();
                currentReadChannel = new FileInputStream(file);
                inChannel = currentReadChannel.getChannel();
            }

            inChannel.read(this.byteBuffer);
        } catch (Exception e) {
            throw new IllegalArgumentException("read error: " + e.getLocalizedMessage());
        }

        return this;
    }

    private boolean isTheSameFile(File f, boolean read) {
        if (read) {
            return (currentReadPath == f.getAbsolutePath());
        }

        return currentWritePath == f.getAbsolutePath();
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

    @JRubyMethod
    public IRubyObject to_s(ThreadContext context) {
        return JavaUtil.convertJavaToRuby(context.getRuntime(), byteBuffer.toString());
    }
}
