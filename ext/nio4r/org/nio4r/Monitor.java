package org.nio4r;

import java.nio.channels.Channel;
import java.nio.channels.SelectableChannel;
import java.nio.channels.SelectionKey;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyIO;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

public class Monitor extends RubyObject {
    private SelectionKey key;
    private RubyIO io;
    private IRubyObject interests, selector, value, closed;

    public Monitor(final Ruby ruby, RubyClass rubyClass) {
        super(ruby, rubyClass);
    }

    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject selectable, IRubyObject interests, IRubyObject selector) {
        this.io        = RubyIO.convertToIO(context, selectable);
        this.interests = interests;
        this.selector  = selector;

        this.value  = context.nil;
        this.closed = context.getRuntime().getFalse();

        return context.nil;
    }

    public void setSelectionKey(SelectionKey key) {
        this.key = key;
        key.attach(this);
    }

    @JRubyMethod(name = "interests=")
    public IRubyObject setInterests(ThreadContext context, IRubyObject interests) {
        if(this.closed == context.getRuntime().getTrue()) {
            throw context.getRuntime().newTypeError("monitor is already closed");
        }

        int interestOps = 0;
        Ruby ruby = context.getRuntime();
        Channel rawChannel = io.getChannel();
        SelectableChannel channel = (SelectableChannel)rawChannel;

        this.interests = interests;

        if(interests == ruby.newSymbol("r")) {
            interestOps = SelectionKey.OP_READ;
        } else if(interests == ruby.newSymbol("w")) {
            interestOps = SelectionKey.OP_WRITE;
        } else if(interests == ruby.newSymbol("rw")) {
            interestOps = SelectionKey.OP_READ|SelectionKey.OP_WRITE;
        }

        if((interestOps & ~(channel.validOps())) == 0) {
            key.interestOps(interestOps);
        } else {
            throw context.getRuntime().newArgumentError("given interests not supported for this IO object");
        }

        return this.interests;
    }

    @JRubyMethod
    public IRubyObject io(ThreadContext context) {
        return io;
    }

    @JRubyMethod
    public IRubyObject selector(ThreadContext context) {
        return selector;
    }

    @JRubyMethod
    public IRubyObject interests(ThreadContext context) {
        return interests;
    }

    @JRubyMethod
    public IRubyObject readiness(ThreadContext context) {
        return Nio4r.interestOpsToSymbol(context.getRuntime(), key.readyOps());
    }

    @JRubyMethod(name = "readable?")
    public IRubyObject isReadable(ThreadContext context) {
        Ruby runtime  = context.getRuntime();
        int  readyOps = this.key.readyOps();

        if((readyOps & SelectionKey.OP_READ) != 0 || (readyOps & SelectionKey.OP_ACCEPT) != 0) {
            return runtime.getTrue();
        } else {
            return runtime.getFalse();
        }
    }

    @JRubyMethod(name = {"writable?", "writeable?"})
    public IRubyObject writable(ThreadContext context) {
        Ruby runtime  = context.getRuntime();
        int  readyOps = this.key.readyOps();

        if((readyOps & SelectionKey.OP_WRITE) != 0 || (readyOps & SelectionKey.OP_CONNECT) != 0) {
            return runtime.getTrue();
        } else {
            return runtime.getFalse();
        }
    }

    @JRubyMethod(name = "value")
    public IRubyObject getValue(ThreadContext context) {
        return this.value;
    }

    @JRubyMethod(name = "value=")
    public IRubyObject setValue(ThreadContext context, IRubyObject obj) {
        this.value = obj;
        return context.nil;
    }

    @JRubyMethod
    public IRubyObject close(ThreadContext context) {
        return close(context, context.getRuntime().getTrue());
    }

    @JRubyMethod
    public IRubyObject close(ThreadContext context, IRubyObject deregister) {
        Ruby runtime = context.getRuntime();
        this.closed = runtime.getTrue();

        if(deregister == runtime.getTrue()) {
            selector.callMethod(context, "deregister", io);
        }

        return context.nil;
    }

    @JRubyMethod(name = "closed?")
    public IRubyObject isClosed(ThreadContext context) {
        return this.closed;
    }
}
