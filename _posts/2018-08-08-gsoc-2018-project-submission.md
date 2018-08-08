---
layout: post
title: GSoC 2018 project submission
---

Here I'd like to summarise my efforts until the publishing day of this post in
the netfilter project as part of the Google Summer of Code 2018 program.  This
will also serve as a product submission which Google requires as a final part of
the program.

I proposed to implement native transparent proxy support in `nf_tables` on both
user- and kernel levels (see my proposal
[here](http://gsoc-blog.ecklm.com/gsoc-2018-proposal/)). This functionality had
already been part of `x_tables` so a part of my job was to refactor the
existing code so that core functions can be used from the new module.

Documentation can be found in the nft(8) man page after applying my patches.

## Socket match implementation

Half of the job was to implement socket matching which can be used to search for
an existing open TCP/UDP socket and its attributes that can be associated with a
packet. It looks for an established or non-zero bound listening socket (possibly
with a non-local address).

Thanks to the structure of the `nf_tables` framework this effort resulted in a
simple implementation which can be used in ip, ip6 and inet tables.

### Main patches related to this part

#### nft

* [src: Introduce socket matching](http://git.netfilter.org/nftables/commit/?id=a02f8c3f6456e9a84a6c3117f2539376b152ba1f)
* [test: py: Add test cases for socket matching](http://git.netfilter.org/nftables/commit/?id=5d22fc81fe27e24dba7a78743318a401353e506b)
* [doc: Add socket expression to man page](http://git.netfilter.org/nftables/commit/?id=6cebd48bfc365b39cb65b6b46cee3f0482408202)
* [src: Expose socket mark via socket expression](http://git.netfilter.org/nftables/commit/?id=9ea0401e385e1dd3f1579a4e772aa876a5e21288)

#### libnftnl

* [src: Add support for native socket matching](http://git.netfilter.org/libnftnl/commit/?id=038d226f2e6cc132de151cc295ea2e4b8805659a)
* [socket: Expose socket mark via socket expression](http://git.netfilter.org/libnftnl/commit/?id=18454d929ac351c0b52ad8454a3905663198658d)

#### kernel

* [netfilter: `nf_tables`: add support for native socket matching](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=554ced0a6e2946562c20d9fffdbaf2aa7da36b1b)
* [netfilter: `nft_socket`: Expose socket mark](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=7d25f8851a2c03319bfa8e56bb40bde2c4621392)

## Tproxy statement implementation

This part was already a bit more complex. I had to extract core functions from
the `xt_TPROXY` implementation and reproduce its use in nft. Now it can be used
to redirect packets to a local socket without changing the packet header in any
way.  This works in ip, ip6 and inet tables, too.

### Main patches related to tproxy statement

#### nft

* [src: Add tproxy support](http://git.netfilter.org/nftables/commit/?id=2be1d52644cf77bb2634fb504a265da480c5e901)
* [tests: py: Add test cases for tproxy support](http://git.netfilter.org/nftables/commit/?id=7dfc5e6586286d72cc294a4a33acbbaa8d2f73ac)
* [doc: Add tproxy statement to man page](http://git.netfilter.org/nftables/commit/?id=029d9b3c16ae2354b6397c325a8dc389c67d970b)

#### libnftnl

* [expr: Add tproxy support](http://git.netfilter.org/libnftnl/commit/?id=c5a98195523416e4fa21fc649b4c61ef653eec32)

#### kernel

* [netfilter: Libify `xt_TPROXY`](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=45ca4e0cf2734f8cc14b43e47c23618215abf1b8)
* [netfilter: `nf_tproxy`: fix possible non-linear access to transport header](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=5711b4e89319c2912f20b2a4f371c1525fc9551d)
* [netfilter: `nft_tproxy`: Move `nf_tproxy_assign_sock()` to `nf_tproxy.h`](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=f286586df68e7733a8e651098401f139dc2e17f4)
* [netfilter: `nf_tables`: Add native tproxy support](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/commit/?id=4ed8eb6570a49931c705512060acd50058d61616)

## Other contributions and summary

Beyond my project proposal I also implemented some fixes to the socket and tproxy
part of the kernel, the nft testing infrastructure and I started to implement
textual representation of standard priorities in the nft tool to make life
easier for sysadmins.

To get all my contributions check the following links:

* [nft patches](http://git.netfilter.org/nftables/log/?qt=grep&q=ecklm94)
* [libnftnl patches](http://git.netfilter.org/libnftnl/log/?qt=grep&q=ecklm94)
* [kernel patches](https://git.kernel.org/pub/scm/linux/kernel/git/pablo/nf-next.git/log/?qt=grep&q=ecklm94)
* [Set/print standard chain prios with textual names (to be accepted)](http://patchwork.ozlabs.org/patch/953128/)
