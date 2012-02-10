package org.nio4r;

import org.jruby.Ruby;
import org.jruby.runtime.load.Library;

public class Nio4r implements Library {
    private Ruby ruby;

    public void load(final Ruby ruby, boolean bln) {
        this.ruby = ruby;
        System.out.println("Hello from Java!");
    }
}
