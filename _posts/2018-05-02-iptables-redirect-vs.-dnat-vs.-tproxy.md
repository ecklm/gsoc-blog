---
layout: post
title: Iptables REDIRECT vs. DNAT vs. TPROXY
---

As getting closer to the task itself (which is to extract the transparent proxy
support from iptables to be available from nftables as well), different
solutions come up which serve similar purposes and the difference between them
is not trivial.

In what they are similar is that we want the clients not to connect directly to
a service (server), but have a network entity (node) in between.

The following figure about my test topology will be useful to discuss the
differences.

```
         +---+ .1           .2 +---+
 (proxy) | X |-----------------| Z | (server)
         +---+   10.0.4.0/24   +---+
           | .101
           |
           | 10.0.0.3.0/24
           |
           | .1
         +---+
         | Y | (client)
         +---+
```

Now see the different possibilities grouped by the iptables target that makes
them available.

There are some solutions for redirecting traffic with the help of the Linux
kernel and iptables. These are DNAT, REDIRECT and TPROXY.

## DNAT

This target in the iptables nat table makes the function of destination nat
available.

This is a quite known concept, if you are familiar with basic networking, you
have probably met this. Low-cost home routers usually call it port forwarding.

What it does is changing the destination addresss (and destination port) to
given values *before the routing decision is made*, and makes the routing
decision be based on the new parameters.  It is an important point here that it
*actually modifies* the IP (and TCP) header and requires connection tracking to
work, as the reply packets should be matched and translated back.

### See an example use-case

Regarding the figure above, we might want to make node `Z` reachable from the
internet without giving public IP address to it. A reason for this can be the
lack of sufficient addresses or security considerations (however NAT is not
considered to be security solution as far as I know). The result is a service
that runs in a private network being accessible through a public gateway.

Lets see an example with iptables:
```
[X]$ iptables --table nat --append PREROUTING --protocol tcp --dport 80 --jump DNAT --to-destination 10.0.4.2
```

This command makes every incoming packets to `X` on port 80 to be forwarded
towards `Z` with a changed IP header.

**Note** that, this solution needs ip forwarding to be enabled in the kernel as
actual routing is done.

### Who knows who?

In this scenario, `Z` knows that the sender of the request is `Y`, and thinks
that `Y` sent the packet directly to it. `Z` therefore will send response
packets to `Y`. Connection tracking is necessary to translate the adress of `Z`
to that of `X` in the response as the source address.

`Y` on the other hand does not know that it is communicating with `Z`, it
believes that `X` receives and replies to its request.

### Who configures this solution?

When DNAT is used, it is configured by the administrator of the service. He/she
wants to hide `Z` behind `X` for whatever reason.

## REDIRECT

This iptables target cannot be associated with a well-known networking solution.
It is like a special DNAT rule where the new destination address is mandatorily
the IP address of the receiving interface.

Here, incoming packets matching the rule have their destination address changed
to the receiving interface's address and optionally their destination port
changed to a specific or a random port (depending on the command).  Similar to
DNAT, the IP (and probably transport layer) header *is modified*.

### See an example use-case

For instance you have a flask server listening on port 8080, but the standard
HTTP port is 80, so you are receiving requests to this port.  The following
iptables role will redirect all tcp packets with the destination port of 80 to
port 8080.

```
[X]$ iptables --table nat --append PREROUTING --protocol tcp --dport 80 --jump REDIRECT --to-ports 8080
```

What is its benefit over DNAT? When I want to redirect traffic on the local
host, DNAT needs the destination address to be added which makes it hard to
maintain if the interface addresses can change. Redirect does not need a
specific IP address to work, so it is more flexible.

**Note** that, using REDIRECT leaves node `Z` untuched, so the service should
run on `X`.

### Who knows who?

In this scenario `Y` does not necessarily know who it is communicating with, `X`
knows `Y` and `Z` is not part of the communication at all.

### Who configures this solution?

REDIRECT is also configured by the administrator of the service, the users know
nothing about this.

## TPROXY

This solution is different from the other two in more aspects.

First, let's see what a proxy is in general. Proxies are nodes/softwares that
are used to stand between the client and the service. The client connects to the
proxy server which then connects to the server through a distinct connection.
This method can be used for various purposes like hiding my own identity from
the server, activity logging or response caching etc.

The first significant difference can be catched here. While DNAT and REDIRECT
had everything done in the kernel, being a proxy means running a specific
software that does the task, the kernel "only" needs to support this.

A proxy can be transparent or non-transparent.

An example to non-transparent proxy can be when you set the address and other
data of the proxy server in your web browser or any other client. In this case
you know about the proxy service and you explicitly configure your device to use
it.

On the other hand, a transparent proxy is invisible for the client. No
configuration is needed on the OS of the client, the network parameters can be
configured to use this solution.

### See an example use-case

Establishing a transparent proxy is a bit more difficult than the other two
solutions. There is a documentation available
[here](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/Documentation/networking/tproxy.txt).
Detailed description of what happens here is out of the scope of the actual post
(I will probably write a separate one about this later).

However, I'd like to describe what can be seen at different points of the
network without any config, after point 1. and point 2. As this is my main
interest, it will be a bit more dateiled than the ones before.

To test this functionality I used [this program](https://git.breakpoint.cc/cgit/fw/tcprdr.git/).

#### Without any config

After the tcprdr program is compiled, the following commands should be run on
different nodes (the order on `Y` should go last).

```
[Z]$ nc --listen --local-port=80

[X]$ ./tcprdr 50080 10.0.4.2 80

[Y]$ telnet 10.0.3.101 50080
```

This solution does not require kernel support. Without `-t` ot `-T` flags,
tcprdr does not set `IP_TRANSPARENT` option on any of the sockets, so it
basically copies bytes from one socket to another.

For now it is nothing special, if run `ss` (formerly `netstat`) on `X`, you see
the following:
```
[X]$ ss --tcp --numeric --processes
StateRecv-Q Send-Q  Local Address:Port    Peer Address:Port
ESTAB0      0       10.0.3.101:50080       10.0.3.1:41088  users:(("tcprdr",pid=460,fd=4))
ESTAB0      0         10.0.4.1:46190       10.0.4.2:80     users:(("tcprdr",pid=460,fd=5))
```

So tcprdr copies bytes from the firs socket to the second and vice versa.

#### With policy routing (point 1.)

```
[Z]$ nc --listen --local-port=80
# A static route is also necessary (later described).
[Z]$ ip route add 10.0.3.101 via 10.0.4.1

[X]$ ./tcprdr -T 50080 10.0.4.2 80

[Y]$ telnet 10.0.3.101 50080
```

Adding the `-T` flag to `tcprdr` enables `IP_TRANSPARENT` option on the outgoing
socket. The output of `ss` is the following:

```
[X]$ ss --tcp --numeric --processes
StateRecv-Q Send-Q  Local Address:Port    Peer Address:Port
ESTAB0      0          10.0.3.101:50080       10.0.3.1:41144  users:(("tcprdr",pid=533,fd=4))
ESTAB0      0            10.0.3.1:41144       10.0.4.2:80     users:(("tcprdr",pid=533,fd=5))
```

This is still without the TPROXY support of the kernel.

The difference here is that `X` uses the IP and TCP source parameters from `Y`
as its own, so `Z` receives packets with the source address of `Y`. The static
route is necessary to be able to respond to these packets.

The policy routing makes it possible for `tcprdr` to hanle packets in response.
This circumstance may be later described in a separate post.

#### With TPROXY support (point 2.)

Adding the iptables rule makes it possible for the proxy application (`tpcrdr`
in our case) to receive packets with the destination port other than what the
listening socket is bound to. Also application-level support is necessary, the
`-t` flag sets the `IP_TRANSPARENT` option on the listening socket. This makes
the following scenario possible.

```
[Z]$ nc --listen --local-port=80

[X]$ ./tcprdr -t -T 50080 10.0.4.2 80

[Y]$ telnet 10.0.3.101 80
```

The sockets on `X` are the following now:
```
[X]$ ss --tcp --numeric --processes
State Recv-Q Send-Q  Local Address:Port    Peer Address:Port
ESTAB 0   0       10.0.3.101:80         10.0.3.1:33104     users:(("tcprdr", pid=634,fd=4))
ESTAB 0   0       10.0.3.1:33104        10.0.4.2:80        users:(("tcprdr", pid=634,fd=5))

[X]$ ss --tcp --numeric --processes --listening
State Recv-Q Send-Q  Local Address:Port    Peer Address:Port
LISTEN0      20            0.0.0.0:50080        0.0.0.0:*     users:(("tcprdr",pid=560,fd=3))
```

As the example shows, `X` receives packets destined to a port that it is not
listening to. TPROXY target makes this possible.

Why is it different from REDIRECT? Because TPROXY does not modify the transport
layer header, it only forwards the packet without any modification. It also
does not require connection tracking as the local port for the connection socket
will be the original destination port.

The benefit of this function over the first two is that no exact port matching
is necessary, so the users do not have to explicitly send SSH
traffic to port 50080 to reach the service, just to mention an example.

*There is also a fourth scenario, when only the `-t` flag is set, that means `X`
uses its own address to communicate with `Z`.*

To sum up this a bit: `IP_TRANSPARENT` socket option makes it possible to
assign an IP address to a socket regardless of whether it is assigned to any of
the network interfaces on our machine or not. None of these require connection
tracking nor ip forwarding option set in the kernel, because the packets are not
forwarded, their payload is only copied from one socket to another.

To decide which socket we want to set transparent, the circumstances should be
known, for now it is enough that it is possible, and the iptables support is
only necessary for the listening socket to work.

### Who knows who?

The answer is different on all three of the described scenarios.

In the firs case, both `Y` and `Z` knows `X` but not each other.

In the second one, `Y` knows `X` and `Z` knows `Y` but not `X`, as the source
address of the socket between `X` and `Z` is that of `Y`.

From this point of view, the third option is the same as the second one, only
the destination port from `Y` can vary.

In the forth scenario, we have the same knowledge as in the first, only the
destination port from `Y` can vary.

### Who configures this solution?

There is another difference from the other solutions here. A proxy is something
that the service provide of the client configures to track and/or improve the
internet access of the client.


