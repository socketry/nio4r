package org.nio4r;

import java.io.IOException;
import java.nio.channels.Channel;
import java.nio.channels.SocketChannel;
import java.nio.channels.SelectableChannel;
import java.nio.channels.SelectionKey;
import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyClass;
import org.jruby.RubyObject;
import org.jruby.RubyIO;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.load.Library;
import org.jruby.runtime.builtin.IRubyObject;

public class Nio4r implements Library {
    private Ruby ruby;

    public void load(final Ruby ruby, boolean bln) {
        this.ruby = ruby;

        RubyModule nio = ruby.defineModule("NIO");

        RubyClass selector = ruby.defineClassUnder("Selector", ruby.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby ruby, RubyClass rc) {
                return new Selector(ruby, rc);
            }
        }, nio);

        selector.defineAnnotatedMethods(Selector.class);

        RubyClass monitor = ruby.defineClassUnder("Monitor", ruby.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby ruby, RubyClass rc) {
                return new Monitor(ruby, rc);
            }
        }, nio);

        monitor.defineAnnotatedMethods(Monitor.class);
    }

    public static int symbolToInterestOps(Ruby ruby, SelectableChannel channel, IRubyObject interest) {
        if(interest == ruby.newSymbol("r")) {
            if((channel.validOps() & SelectionKey.OP_ACCEPT) != 0) {
              return SelectionKey.OP_ACCEPT;
            } else {
              return SelectionKey.OP_READ;
            }
        } else if(interest == ruby.newSymbol("w")) {
            if(channel instanceof SocketChannel && !((SocketChannel)channel).isConnected()) {
                return SelectionKey.OP_CONNECT;
            } else {
                return SelectionKey.OP_WRITE;
            }
        } else if(interest == ruby.newSymbol("rw")) {
              return symbolToInterestOps(ruby, channel, ruby.newSymbol("r")) |
                     symbolToInterestOps(ruby, channel, ruby.newSymbol("w"));
        } else {
            throw ruby.newArgumentError("invalid interest type: " + interest);
        }
    }

    public class Selector extends RubyObject {
        private java.nio.channels.Selector selector;

        public Selector(final Ruby ruby, RubyClass rubyClass) {
            super(ruby, rubyClass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            try {
                selector = java.nio.channels.Selector.open();
            } catch(IOException ie) {
                throw context.runtime.newIOError(ie.getLocalizedMessage());
            }

            return context.nil;
        }

        @JRubyMethod
        public IRubyObject register(ThreadContext context, IRubyObject io, IRubyObject interest) {
            Ruby runtime = context.getRuntime();
            Channel raw_channel = ((RubyIO)io).getChannel();

            if(!(raw_channel instanceof SelectableChannel)) {
                throw runtime.newArgumentError("not a selectable IO object");
            }

            SelectableChannel channel = (SelectableChannel)raw_channel;

            try {
                channel.configureBlocking(false);
            } catch(IOException ie) {
                throw runtime.newIOError(ie.getLocalizedMessage());
            }

            int interestOps = Nio4r.symbolToInterestOps(runtime, channel, interest);
            SelectionKey key;

            try {
                key = channel.register(selector, interestOps);
            } catch(java.lang.IllegalArgumentException ia) {
                throw runtime.newArgumentError("invalid interest type:" + interest);
            } catch(java.nio.channels.ClosedChannelException cce) {
                throw context.runtime.newIOError(cce.getLocalizedMessage());
            }

            RubyClass monitorClass = runtime.getModule("NIO").getClass("Monitor");
            Monitor monitor = (Monitor)monitorClass.newInstance(context, io, null);
            monitor.setSelectionKey(key);

            return monitor;
        }
    }

    public class Monitor extends RubyObject {
        private SelectionKey key;

        public Monitor(final Ruby ruby, RubyClass rubyClass) {
            super(ruby, rubyClass);
        }

        public void setSelectionKey(SelectionKey k) {
            key = k;
        }
    }
}
