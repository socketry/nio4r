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
        RubyClass overflowErrorClass = context.runtime.getModule("NIO")
                                                      .getClass("ByteBuffer")
                                                      .getClass("OverflowError");

        return context.runtime.newRaiseException(overflowErrorClass, message);
    }

    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject capacity) {
        Ruby ruby = context.getRuntime();

        this.byteBuffer = java.nio.ByteBuffer.allocate(RubyNumeric.num2int(capacity));

        return this;
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

    @JRubyMethod(name = "get")
    public IRubyObject get(ThreadContext context) {
        ArrayList<Byte> temp = new ArrayList<Byte>();

        while (this.byteBuffer.hasRemaining()) {
            temp.add(this.byteBuffer.get());
        }

        return JavaUtil.convertJavaToRuby(context.getRuntime(), new String(toPrimitives(temp)));
    }

    @JRubyMethod(name = "read_next")
    public IRubyObject readNext(ThreadContext context, IRubyObject count) {
        int c = RubyNumeric.num2int(count);

        if (c < 1) {
            throw new IllegalArgumentException();
        }

        if (c <= this.byteBuffer.remaining()) {
            org.jruby.util.ByteList temp = new org.jruby.util.ByteList(c);

            while (c > 0) {
                temp.append(this.byteBuffer.get());
                c--;
            }

            return context.runtime.newString(temp);
        }

        return RubyString.newEmptyString(context.runtime);
    }

    private byte[] toPrimitives(ArrayList<Byte> oBytes) {
        byte[] bytes = new byte[oBytes.size()];

        for (int i = 0; i < oBytes.size(); i++) {
            bytes[i] = (oBytes.get(i) == null) ? " ".getBytes()[0] : oBytes.get(i);
        }

        return bytes;
    }

    @JRubyMethod(name = "write_to")
    public IRubyObject writeTo(ThreadContext context, IRubyObject f) {
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

    @JRubyMethod(name = "read_from")
    public IRubyObject readFrom(ThreadContext context, IRubyObject f) {
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

    @JRubyMethod(name = "remaining")
    public IRubyObject remainingPositions(ThreadContext context) {
        int count = this.byteBuffer.remaining();
        return context.getRuntime().newFixnum(count);
    }

    @JRubyMethod(name = "remaining?")
    public IRubyObject hasRemaining(ThreadContext context) {
        if (this.byteBuffer.hasRemaining()) {
            return context.getRuntime().getTrue();
        }

        return context.getRuntime().getFalse();
    }

    @JRubyMethod(name = "offset?")
    public IRubyObject getOffset(ThreadContext context) {
        int offset = this.byteBuffer.arrayOffset();
        return context.getRuntime().newFixnum(offset);
    }

    /**
     * Check whether the two ByteBuffers are the same.
     *
     * @param context
     * @param ob      : The RubyObject which needs to be check
     * @return
     */
    @JRubyMethod(name = "equals?")
    public IRubyObject equals(ThreadContext context, IRubyObject obj) {
        Object o = JavaUtil.convertRubyToJava(obj);

        if(!(o instanceof ByteBuffer)) {
            return context.getRuntime().getFalse();
        }

        if(this.byteBuffer.equals(((ByteBuffer)o).getBuffer())) {
            return context.getRuntime().getTrue();
        } else {
            return context.getRuntime().getFalse();
        }
    }

    /**
     * Flip capability provided by the java nio.ByteBuffer
     * buf.put(magic);    // Prepend header
     * in.read(buf);      // Read data into rest of buffer
     * buf.flip();        // Flip buffer
     * out.write(buf);    // Write header + data to channel
     *
     * @param context
     * @return
     */
    @JRubyMethod
    public IRubyObject flip(ThreadContext context) {
        this.byteBuffer.flip();
        return this;
    }

    /**
     * Rewinds the buffer. Usage in java is like
     * out.write(buf);    // Write remaining data
     * buf.rewind();      // Rewind buffer
     * buf.get(array);    // Copy data into array
     *
     * @param context
     * @return
     */
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

    /**
     * Removes all the content in the byteBuffer
     *
     * @param context
     * @return
     */
    @JRubyMethod
    public IRubyObject clear(ThreadContext context) {
        this.byteBuffer.clear();
        return this;
    }

    @JRubyMethod
    public IRubyObject compact(ThreadContext context) {
        byteBuffer.compact();
        return this;
    }

    @JRubyMethod(name = "capacity")
    public IRubyObject capacity(ThreadContext context) {
        int cap = this.byteBuffer.capacity();
        return context.getRuntime().newFixnum(cap);
    }

    @JRubyMethod
    public IRubyObject position(ThreadContext context, IRubyObject newPosition) {
        int position = RubyNumeric.num2int(newPosition);
        this.byteBuffer.position(position);
        return this;
    }

    @JRubyMethod(name = "limit")
    public IRubyObject limit(ThreadContext context, IRubyObject newLimit) {
        int limit = RubyNumeric.num2int(newLimit);
        this.byteBuffer.limit(limit);
        return this;
    }

    @JRubyMethod(name = "limit?")
    public IRubyObject limit(ThreadContext context) {
        int lmt = this.byteBuffer.limit();
        return context.getRuntime().newFixnum(lmt);
    }

    @JRubyMethod(name = "to_s")
    public IRubyObject to_String(ThreadContext context) {
        return JavaUtil.convertJavaToRuby(context.getRuntime(), byteBuffer.toString());
    }

    public java.nio.ByteBuffer getBuffer() {
        return this.byteBuffer;
    }
}
