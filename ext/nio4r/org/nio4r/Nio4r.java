package org.nio4r;

import java.util.Iterator;
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
import org.jruby.RubyNumeric;
import org.jruby.RubyArray;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.load.Library;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.Block;

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

    public static IRubyObject interestOpsToSymbol(Ruby ruby, int interestOps) {
        switch(interestOps) {
            case SelectionKey.OP_READ:
            case SelectionKey.OP_ACCEPT:
                return ruby.newSymbol("r");
            case SelectionKey.OP_WRITE:
            case SelectionKey.OP_CONNECT:
                return ruby.newSymbol("w");
            case SelectionKey.OP_READ | SelectionKey.OP_CONNECT:
            case SelectionKey.OP_READ | SelectionKey.OP_WRITE:
                return ruby.newSymbol("rw");
            default:
                throw ruby.newArgumentError("unknown interest op combination");
        }
    }

    // Remove connect interest from connected sockets
    // See: http://stackoverflow.com/questions/204186/java-nio-select-returns-without-selected-keys-why
    public static void processKey(SelectionKey key) {
        if((key.readyOps() & SelectionKey.OP_CONNECT) != 0) {
            int interestOps = key.interestOps();

            interestOps &= ~SelectionKey.OP_CONNECT;
            interestOps |=  SelectionKey.OP_WRITE;

            key.interestOps(interestOps);
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
        public IRubyObject close(ThreadContext context) {
            try {
                selector.close();
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

        @JRubyMethod
        public synchronized IRubyObject select(ThreadContext context) {
            return select(context, context.nil);
        }

        @JRubyMethod
        public synchronized IRubyObject select(ThreadContext context, IRubyObject timeout) {
            Ruby runtime = context.getRuntime();
            int ready = doSelect(runtime, timeout);

            /* Timeout or wakeup */
            if(ready <= 0)
                return context.nil;

            RubyArray array = runtime.newArray(selector.selectedKeys().size());
            Iterator selectedKeys = selector.selectedKeys().iterator();
            while (selectedKeys.hasNext()) {
                SelectionKey key = (SelectionKey)selectedKeys.next();
                Nio4r.processKey(key);
                selectedKeys.remove();
                array.add(key.attachment());
            }

            return array;
        }

        @JRubyMethod
        public synchronized IRubyObject select_each(ThreadContext context, Block block) {
            return select_each(context, context.nil, block);
        }

        @JRubyMethod
        public synchronized IRubyObject select_each(ThreadContext context, IRubyObject timeout, Block block) {
            Ruby runtime = context.getRuntime();
            int ready = doSelect(runtime, timeout);

            /* Timeout or wakeup */
            if(ready <= 0)
                return context.nil;

            Iterator selectedKeys = selector.selectedKeys().iterator();
            while (selectedKeys.hasNext()) {
                SelectionKey key = (SelectionKey)selectedKeys.next();
                Nio4r.processKey(key);
                selectedKeys.remove();
                block.call(context, (IRubyObject)key.attachment());
            }

            return context.nil;
        }

        private int doSelect(Ruby runtime, IRubyObject timeout) {
            try {
                if(timeout.isNil()) {
                    return selector.select();
                } else {
                    double t = RubyNumeric.num2dbl(timeout);
                    if(t == 0) {
                        return selector.selectNow();
                    } else if(t < 0) {
                        throw runtime.newArgumentError("time interval must be positive");
                    } else {
                        return selector.select((long)(t * 1000));
                    }
                }
            } catch(IOException ie) {
                throw runtime.newIOError(ie.getLocalizedMessage());
            }
        }

        @JRubyMethod
        public IRubyObject wakeup(ThreadContext context) {
            selector.wakeup();
            return context.nil;
        }
    }

    public class Monitor extends RubyObject {
        private SelectionKey key;
        private RubyIO io;

        public Monitor(final Ruby ruby, RubyClass rubyClass) {
            super(ruby, rubyClass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context, IRubyObject selectable) {
            io = (RubyIO)selectable;
            return context.nil;
        }

        public void setSelectionKey(SelectionKey k) {
            key = k;
            key.attach(this);
        }

        @JRubyMethod
        public IRubyObject interests(ThreadContext context) {
            return Nio4r.interestOpsToSymbol(context.getRuntime(), key.interestOps());
        }

        @JRubyMethod
        public IRubyObject readiness(ThreadContext context) {
            return Nio4r.interestOpsToSymbol(context.getRuntime(), key.readyOps());
        }
    }
}
