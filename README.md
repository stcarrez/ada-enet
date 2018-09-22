# Ada Embedded Network Stack

[![Build Status](https://img.shields.io/jenkins/s/http/jenkins.vacs.fr/Ada-Enet.svg)](http://jenkins.vacs.fr/job/Ada-Enet/)
[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)](LICENSE)

This library is a small network stack that implements ARP, IPv4, UDP, DNS and DHCP protocols
on top of an Ethernet driver.  It can be compiled for a STM32F746 or a STM32F769 board
to provide IPv4 network access to your project.  This library is used
by the EtherScope project to read network packets and analyze the traffic
(See https://github.com/stcarrez/etherscope).  The following protocols are supported:

* IPv4 ([RFC 791](https://tools.ietf.org/html/rfc791))
* ICMP ([RFC 792](https://tools.ietf.org/html/rfc792))
* UDP ([RFC 768](https://tools.ietf.org/html/rfc768))
* ARP ([RFC 826](https://tools.ietf.org/html/rfc826))
* DNS ([RFC 1035](https://tools.ietf.org/html/rfc1035))
* DHCPv4 ([RFC 2131](https://tools.ietf.org/html/rfc2131))
* NTP ([RFC 5905](https://tools.ietf.org/html/rfc5905))

Before build the library you will need:

* Ada_Drivers_Library
  https://github.com/AdaCore/Ada_Drivers_Library.git

* The GNAT 2018 Ada compiler for ARM
  http://libre.adacore.com/

The library supports at least two boards and to simplify and help in the configuration
and build process, you must run the *configure* script to configure the GNAT project
files according to your target board.  Run configure:

## STM32F746

```shell
  configure --with-board=stm32f746
```

## STM32F769

```shell
  configure --with-board=stm32f769
```


The Ada_Drivers_Library is imported as part of a Git submodule.  To checkout everything, you may use
the following commands:

```shell
  make checkout
```

Before building, make sure you have the GNAT ARM 2018 Ada compiler in your search path.
Then, you may have to run the following command to configure everything for gprbuild:

```shell
  gprconfig --target=arm-eabi
```

You can build the library with:

```shell
  gprbuild --target=arm-eabi -Panet_stm32f746 -p
```

Note: if gprbuild command fails with:

```
gprconfig: can't find a toolchain for the following configuration:
gprconfig: language 'ada', target 'arm-eabi', default runtime
```

then, run again the gprconfig command and select the correct Ada ARM compiler.

Several demo applications are provided to illustrate how you can use the different
network features.  The demo applications use the [DHCP Client](https://github.com/stcarrez/ada-enet/wiki/Net_DHCP)
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
