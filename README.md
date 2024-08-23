# Ada Embedded Network Stack

[![Alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/enet.json)](https://alire.ada.dev/crates/enet.html)
[![Build with Alire](https://github.com/stcarrez/ada-enet/actions/workflows/alire.yml/badge.svg)](https://github.com/stcarrez/ada-enet/actions/workflows/alire.yml)
[![Build Status](https://img.shields.io/jenkins/s/http/jenkins.vacs.fr/Ada-Enet.svg)](http://jenkins.vacs.fr/job/Ada-Enet/)
[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)](LICENSE)

This library is a modular network stack that implements ARP, IPv4, UDP,
DNS, and DHCP protocols on top of an Ethernet driver. It is divided into
two parts: a hardware-independent core and a specific driver for STM32F7xx
and STM32F4xx boards. This allows you to provide IPv4 network access to your
project with ease. The library is utilized by the EtherScope project to
capture and analyze network traffic (See
https://github.com/stcarrez/etherscope).

The following protocols are supported:

* IPv4 ([RFC 791](https://tools.ietf.org/html/rfc791))
* ICMP ([RFC 792](https://tools.ietf.org/html/rfc792))
* UDP ([RFC 768](https://tools.ietf.org/html/rfc768))
* ARP ([RFC 826](https://tools.ietf.org/html/rfc826))
* DNS ([RFC 1035](https://tools.ietf.org/html/rfc1035))
* DHCPv4 ([RFC 2131](https://tools.ietf.org/html/rfc2131))
* NTP ([RFC 5905](https://tools.ietf.org/html/rfc5905))

## Installation and Usage

The core part has no dependencies, while the STM32 driver depends on
the [ethernet](https://github.com/reznikmm/ethernet) crate, as it implements
the MDIO interface defined there.

To use the library with Alire just run `alr with enet` (for the core part).
To use the STM32 driver run `alr with enet_stm32`.

See more details on [the Wiki](https://github.com/stcarrez/ada-enet/wiki).

## Examples

We provide a simple [ping_text_io](demos/ping_text_io/) demo. This demo is
independent of any particular board, and you can build it by providing the
required runtime, for example:

```shell
alr -C demos/ping_text_io/ build -- -XRUNTIME=embedded-stm32f746disco
```

When you flash the executable, the board will receive an IP address via DHCP
and ping the default gateway. You can see the ping messages emitted using the
standard Ada.Text_IO routines.

Four additional demo applications are provided to illustrate how you can use
the different network features. They require an STM32F429, STM32F746, or
STM32F769 Discovery board to run. These examples depend on the
[Ada_Drivers_Library](https://github.com/AdaCore/Ada_Drivers_Library.git) and
do not use Alire for building. Instead, make sure you have the GNAT ARM cross
toolchain in your `PATH`, then run:

```shell
configure --with-board=stm32f746 # or stm32f769 or stm32f429
```

Then, execute `make checkout` to download the necessary dependencies.
Finally, `make all` will build all four demos.

The demo applications use the [DHCP Client](https://github.com/stcarrez/ada-enet/wiki/Net_DHCP)
to get an IPv4 address and obtain the default gateway and DNS.

For some demo applications, you can switch to a static IP configuration by editing the file
**demos/utils/demo.adb** and un-comment and modify the following lines:

```ada
   Ifnet.Ip := (192, 168, 1, 2);
   Ifnet.Gateway := (192, 168, 1, 240);
   Ifnet.Dns := (192, 168, 1, 240);
```

and disable the DHCP configuration by commenting the line:

```ada
   -- Dhcp.Initialize (Ifnet'Access);
```

## Ping

The ping application implements a simple ping on several hosts and displays
the ping counters on the STM32F LCD display.  The application will also answer
to ping requests.

To build the Ping application you may run:

```shell
  make ping
```

And to flash the ping image, you can use:

```shell
  make flash-ping
```

## Echo

The echo application shows a simple UDP server that echos the received packet (RFC 862).
It listens on UDP port 7, loops to wait for UDP packets, returns them and increment a
counter of received packets which is displayed on the STM32 LCD display.
The echo application is described in the article: [Simple UDP Echo Server on STM32F746](http://blog.vacs.fr/vacs/blogs/post.html?post=2016/12/04/Simple-UDP-Echo-Server-on-STM32F746)

To build the Echo application you may run:

```shell
  make echo
```

And to flash the echo image, you can use:

```shell
  make flash-echo
```

And to test the echo UDP server, you may use the **socat** command on GNU/Linux.
For example:

```shell
  echo -n 'Hello! Ada is great!' | socat - UDP:192.168.1.156:7
```

## DNS

The dns application shows a simple DNS client resolver that queries a DNS to resolve a list
of hosts. 

To build the dns application you may run:

```shell
  make dns
```

And to flash the dns image, you can use:

```shell
  make flash-dns
```

## Time

The time application uses the NTP client to retrieve the GMT date from a NTP server
and it displays the GMT time as soon as the NTP synchronisation is obtained.
The application will also answer to ping requests.

To build the Time application you may run:

```shell
  make time
```

And to flash the time image, you can use:

```shell
  make flash-time
```

## Documentation

- https://github.com/stcarrez/ada-enet/wiki
- [NTP Client](https://github.com/stcarrez/ada-enet/wiki/Net_NTP)
- [DHCP Client](https://github.com/stcarrez/ada-enet/wiki/Net_DHCP)
- [Using the Ada Embedded Network STM32 Ethernet Driver](http://blog.vacs.fr/vacs/blogs/post.html?post=2016/09/29/Using-the-Ada-Embedded-Network-STM32-Ethernet-Driver)
- [Simple UDP Echo Server on STM32F746](http://blog.vacs.fr/vacs/blogs/post.html?post=2016/12/04/Simple-UDP-Echo-Server-on-STM32F746)

## License

[Apache-2.0](LICENSE.txt) © Stephane Carrez
