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

