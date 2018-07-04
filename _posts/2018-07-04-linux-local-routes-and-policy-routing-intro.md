---
layout: post
title: Linux local routes and policy routing intro
---

In the [tproxy documentation](https://git.kernel.org/pub/scm/Linux/kernel/git/pablo/nf-next.git/tree/Documentation/networking/tproxy.txt)
there is a description about how to set up transparent proxying with the help of
iptables and polcy routing. As this is quite a special use-case I met some
questions wich are not so obvious, neither are the answers. In this post you can
read a little intro about this topic.

The relevant commands are the following:

```bash
$ iptables -t mangle -N DIVERT
$ iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT
$ iptables -t mangle -A DIVERT -j MARK --set-mark 1
$ iptables -t mangle -A DIVERT -j ACCEPT

$ ip rule add fwmark 1 lookup 100
$ ip route add local 0.0.0.0/0 dev lo table 100
```

These operations have to be made so that the sockets assigned to non-local IP
can receive network packets.

When I was preparing my test environment two questions occured to me: *How does
the kernel not know that there is a socket assigned to this address and not
forward packets to it? And how does it work for sockets that have addresses that
are assigned to any of the local iterface addresses?*

The necessary information to answer these questions are in the man pages
ip-route(8) and ip-rule(8), but it took some time for me to find out where I can
read about this and how the pieces are connected. So let's have a look at the
starting points of such a discovery.

We have to take a tour around multiple routing tables in Linux.  There is a
routing table called 'main' which is known by most of the sysadmins.  It stores
the default route and all external routes by default. Although there is more
under the surface, which is the answer to the second question. All the local
interface and broadcast adresses are set up in the 'local' routing table by the
OS. You can list them with `ip route show table local`. For most of the cases
the users do not need to manipulate this table so it is mostly unknown and
untouched by human beings, however, as such it is just as important as the
'main' table.

Actually the answer to the first question is also here. The local table is
handled by the OS and by default it only adds addresses of the interfaces to it.
Creating a new socket does not insert any rule in the local table. This way, if
we use a non-local address, the approppriate routing table entry will be
missing.  There is certainly some ways to solve transparent proxy support with
only these two tables, but it would include routing table hacking from the proxy
program, or some other ugly solution. Hence we use policy routing to do it.

Policy routing in the Linux kernel is enabled by the `IP_MULTIPLE_TABLES` and
`IPV6_MULTIPLE_TABLES` kernel config parameters which are enabled by default for
desktop and server environments.  The most common tool to use this ability is
the `ip rule` command. In its man page it describes the structure and priorities
and how it implements policy routing. In our example we use the packet mark as a
selector and as we mark all packets that have a corresponding socket, it just
works fine. (**Note:** I strugled a bit with what `lookup` means as it is not
documented. It is supposedly a deprecated command but it is equivalent to
`table` as it can be seen in the [source code](https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/tree/ip/iprule.c?id=f686f764682745daf6a93b0a6330ba42a961f858#n583).)

Basically not much more is necessary to understand what happens behind the
scenes and it is quite the same with IPv6. Read the manuals, and happy networking!
