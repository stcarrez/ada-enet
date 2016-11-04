# Ada Embedded Network Stack

[![License](http://img.shields.io/badge/license-APACHE2-blue.svg)](LICENSE)

This library is a small network stack that implements ARP, IPv4 protocols
on top of an Ethernet driver.  It can be compiled for a STM32F746 board
to provide IPv4 network access to your project.  This library is used
by the EtherScope project to read network packets and analyze the traffic
(See https://github.com/stcarrez/etherscope).

Before build the library you will need:

* Ada_Drivers_Library
  https://github.com/AdaCore/Ada_Drivers_Library.git

* The GNAT Ada compiler for ARM
  http://libre.adacore.com/

You can build the library with:

  arm-eabi-gnatmake -Panet_stm32f746 -p

The ping application implements a simple ping on several hosts and displays
the ping counters on the STM32F LCD display.  The application has a static
IP configuration with IP address **192.168.1.2** and gateway **192.168.1.240**.
The application will continuously ping the hosts (192.168.1.1, 192.168.1.129,
192.168.1.240, 192.168.1.254 and 8.8.8.8).  The application will also answer
to ping requests.  If the static configuration is not suitable for your
network, change the lines in ping.adb:

>   --  Static IP interface, default netmask and no gateway.
>   Receiver.Ifnet.Ip := (192, 168, 1, 2);
>   Receiver.Ifnet.Gateway := (192, 168, 1, 240);

