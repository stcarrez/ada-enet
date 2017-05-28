-----------------------------------------------------------------------
--  net -- Network stack
--  Copyright (C) 2016, 2017 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------
with Interfaces;
with System;

--  == Embedded Network Stack ==
--  The <b>Embedded Network Stack</b> is a small IPv4 network stack intended to be
--  used by small embedded Ada applications.
--
--  @include net-buffers.ads
--  @include net-interfaces.ads
--  @include net-protos-arp.ads
package Net is

   pragma Pure;

   --  The network stack interrupt priority.  It is used to configure the Ethernet driver
   --  interrupt priority as well as the protected objects that could depend on it.
   Network_Priority : constant System.Interrupt_Priority := System.Interrupt_Priority'First;

   subtype Uint8 is Interfaces.Unsigned_8;
   subtype Uint16 is Interfaces.Unsigned_16;
   subtype Uint32 is Interfaces.Unsigned_32;
   subtype Uint64 is Interfaces.Unsigned_64;

   --  Length of an IPv4 packet.
   type Ip_Length is new Uint16;

   --  IPv4 address representation.
   type Ip_Addr is array (1 .. 4) of Uint8;

   --  Ethernet address representation.
   type Ether_Addr is array (1 .. 6) of Uint8;

   --  The error code returned by some opeartions.
   type Error_Code is (EOK,         --  No error.
                       ENOBUFS,     --  No buffer for the operation.
                       ENETUNREACH, --  Network unreachable.
                       EINPROGRESS  --  Operation is in progress.
                      );

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   --  Returns true if the IPv4 address is a multicast address.
   function Is_Multicast (IP : in Ip_Addr) return Boolean;

end Net;
