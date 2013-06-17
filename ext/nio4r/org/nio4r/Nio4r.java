package org.nio4r;

import java.util.Iterator;
import java.util.Map;
import java.util.HashMap;
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
            int interestOps = 0;

            /* nio4r emulates the POSIX behavior, which is sloppy about allowed modes */
            if((channel.validOps() & (SelectionKey.OP_READ | SelectionKey.OP_ACCEPT)) != 0) {
                interestOps |= symbolToInterestOps(ruby, channel, ruby.newSymbol("r"));
            }

            if((channel.validOps() & (SelectionKey.OP_WRITE | SelectionKey.OP_CONNECT)) != 0) {
                interestOps |= symbolToInterestOps(ruby, channel, ruby.newSymbol("w"));
            }

            return interestOps;
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

    public class Selector extends RubyObject {
        private java.nio.channels.Selector selector;
        private HashMap<SelectableChannel,SelectionKey> cancelledKeys;

        public Selector(final Ruby ruby, RubyClass rubyClass) {
            super(ruby, rubyClass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            this.cancelledKeys = new HashMap<SelectableChannel,SelectionKey>();
            try {
                this.selector = java.nio.channels.Selector.open();
            } catch(IOException ie) {
                throw context.runtime.newIOError(ie.getLocalizedMessage());
            }

            return context.nil;
        }

        @JRubyMethod
        public IRubyObject close(ThreadContext context) {
            try {
                this.selector.close();
            } catch(IOException ie) {
                throw context.runtime.newIOError(ie.getLocalizedMessage());
            }

            return context.nil;
        }

        @JRubyMethod(name = "closed?")
        public IRubyObject isClosed(ThreadContext context) {
            Ruby runtime = context.getRuntime();
            return this.selector.isOpen() ? runtime.getFalse() : runtime.getTrue();
        }

        @JRubyMethod(name = "empty?")
        public IRubyObject isEmpty(ThreadContext context) {
            Ruby runtime = context.getRuntime();
            return this.selector.keys().isEmpty() ? runtime.getTrue() : runtime.getFalse();
        }

        @JRubyMethod
        public IRubyObject register(ThreadContext context, IRubyObject io, IRubyObject interests) {
            Ruby runtime = context.getRuntime();
            Channel rawChannel = RubyIO.convertToIO(context, io).getChannel();

            if(!this.selector.isOpen()) {
                throw context.getRuntime().newIOError("selector is closed");
            }

            if(!(rawChannel instanceof SelectableChannel)) {
                throw runtime.newArgumentError("not a selectable IO object");
            }

            SelectableChannel channel = (SelectableChannel)rawChannel;

            try {
                channel.configureBlocking(false);
            } catch(IOException ie) {
                throw runtime.newIOError(ie.getLocalizedMessage());
            }

            int interestOps = Nio4r.symbolToInterestOps(runtime, channel, interests);
            SelectionKey key;

            key = this.cancelledKeys.remove(channel);

            if(key != null) {
                key.interestOps(interestOps);
            } else {
                try {
                    key = channel.register(this.selector, interestOps);
                } catch(java.lang.IllegalArgumentException ia) {
                    throw runtime.newArgumentError("mode not supported for this object: " + interests);
                } catch(java.nio.channels.ClosedChannelException cce) {
                    throw context.runtime.newIOError(cce.getLocalizedMessage());
                }
            }

            RubyClass monitorClass = runtime.getModule("NIO").getClass("Monitor");
            Monitor monitor = (Monitor)monitorClass.newInstance(context, io, interests, this, null);
            monitor.setSelectionKey(key);

            return monitor;
        }

        @JRubyMethod
        public IRubyObject deregister(ThreadContext context, IRubyObject io) {
            Ruby runtime = context.getRuntime();
            Channel rawChannel = RubyIO.convertToIO(context, io).getChannel();

            if(!(rawChannel instanceof SelectableChannel)) {
                throw runtime.newArgumentError("not a selectable IO object");
            }

            SelectableChannel channel = (SelectableChannel)rawChannel;
            SelectionKey key = channel.keyFor(this.selector);

            if(key == null)
                return context.nil;

            Monitor monitor = (Monitor)key.attachment();
            monitor.close(context, runtime.getFalse());
            cancelledKeys.put(channel, key);

            return monitor;
        }

        @JRubyMethod(name = "registered?")
        public IRubyObject isRegistered(ThreadContext context, IRubyObject io) {
            Ruby runtime = context.getRuntime();
            Channel rawChannel = RubyIO.convertToIO(context, io).getChannel();

            if(!(rawChannel instanceof SelectableChannel)) {
                throw runtime.newArgumentError("not a selectable IO object");
            }

            SelectableChannel channel = (SelectableChannel)rawChannel;
            SelectionKey key = channel.keyFor(this.selector);

            if(key == null)
                return context.nil;


            if(((Monitor)key.attachment()).isClosed(context) == runtime.getTrue()) {
                return runtime.getFalse();
            } else {
                return runtime.getTrue();
            }
        }

        @JRubyMethod
        public synchronized IRubyObject select(ThreadContext context, Block block) {
            return select(context, context.nil, block);
        }

        @JRubyMethod
        public synchronized IRubyObject select(ThreadContext context, IRubyObject timeout, Block block) {
            Ruby runtime = context.getRuntime();
            int ready = doSelect(runtime, context, timeout);

            /* Timeout or wakeup */
            if(ready <= 0)
                return context.nil;

            RubyArray array = null;
            if(!block.isGiven()) {
                array = runtime.newArray(this.selector.selectedKeys().size());
            }

            Iterator selectedKeys = this.selector.selectedKeys().iterator();
            while(selectedKeys.hasNext()) {
                SelectionKey key = (SelectionKey)selectedKeys.next();
                processKey(key);
                selectedKeys.remove();

                if(block.isGiven()) {
                    block.call(context, (IRubyObject)key.attachment());
                } else {
                    array.add(key.attachment());
                }
            }

            if(block.isGiven()) {
                return RubyNumeric.int2fix(runtime, ready);
            } else {
                return array;
            }
        }

        /* Run the selector */
        private int doSelect(Ruby runtime, ThreadContext context, IRubyObject timeout) {
            int result;

            cancelKeys();
            try {
                context.getThread().beforeBlockingCall();
                if(timeout.isNil()) {
                    result = this.selector.select();
                } else {
                    double t = RubyNumeric.num2dbl(timeout);
                    if(t == 0) {
                        result = this.selector.selectNow();
                    } else if(t < 0) {
                        throw runtime.newArgumentError("time interval must be positive");
                    } else {
                        result = this.selector.select((long)(t * 1000));
                    }
                }
                context.getThread().afterBlockingCall();
                return result;
            } catch(IOException ie) {
                throw runtime.newIOError(ie.getLocalizedMessage());
            }
        }

        /* Flush our internal buffer of cancelled keys */
        private void cancelKeys() {
            Iterator cancelledKeys = this.cancelledKeys.entrySet().iterator();
            while(cancelledKeys.hasNext()) {
                Map.Entry entry = (Map.Entry)cancelledKeys.next();
                SelectionKey key = (SelectionKey)entry.getValue();
                key.cancel();
                cancelledKeys.remove();
            }
        }

        // Remove connect interest from connected sockets
        // See: http://stackoverflow.com/questions/204186/java-nio-select-returns-without-selected-keys-why
        private void processKey(SelectionKey key) {
            if((key.readyOps() & SelectionKey.OP_CONNECT) != 0) {
                int interestOps = key.interestOps();

                interestOps &= ~SelectionKey.OP_CONNECT;
                interestOps |=  SelectionKey.OP_WRITE;

                key.interestOps(interestOps);
            }
        }

        @JRubyMethod
        public IRubyObject wakeup(ThreadContext context) {
            if(!this.selector.isOpen()) {
                throw context.getRuntime().newIOError("selector is closed");
            }

            this.selector.wakeup();
            return context.nil;
        }
    }

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
}
