-----------------------------------------------------------------------
--  net-headers -- Network headers
--  Copyright (C) 2016 Stephane Carrez
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
package Net.Headers is

   --  Convert integers to network byte order.
   function To_Network (Val : in Uint32) return Uint32;
   function To_Network (Val : in Uint16) return Uint16;

   --  Convert integers to host byte order.
   function To_Host (Val : in Uint32) return Uint32;
   function To_Host (Val : in Uint16) return Uint16;

   --  Ethernet header as defined for 802.3 Ethernet packet.
   type Ether_Header is record
      Ether_Dhost : Ether_Addr;
      Ether_Shost : Ether_Addr;
      Ether_Type  : Uint16;
   end record;
   type Ether_Header_Access is access all Ether_Header;

   type Arp_Header is record
      Ar_Hdr      : Uint16;
      Ar_Pro      : Uint16;
      Ar_Hln      : Uint8;
      Ar_Pln      : Uint8;
      Ar_Op       : Uint16;
   end record;

   type Ether_Arp is record
      Ea_Hdr      : Arp_Header;
      Arp_Sha     : Ether_Addr;
      Arp_Spa     : Ip_Addr;
      Arp_Tha     : Ether_Addr;
      Arp_Tpa     : Ip_Addr;
   end record;
   type Ether_Arp_Access is access all Ether_Arp;

   --  ARP Ethernet packet
   type Arp_Packet is record
      Ethernet : Net.Headers.Ether_Header;
      Arp      : Net.Headers.Ether_Arp;
   end record;
   type Arp_Packet_Access is access all Arp_Packet;

   --  IP packet header RFC 791.
   type IP_Header is record
      Ip_Ihl      : Uint8;
      Ip_Tos      : Uint8;
      Ip_Len      : Uint16;
      Ip_Id       : Uint16;
      Ip_Off      : Uint16;
      Ip_Ttl      : Uint8;
      Ip_P        : Uint8;
      Ip_Sum      : Uint16;
      Ip_Src      : Ip_Addr;
      Ip_Dst      : Ip_Addr;
   end record;
   type IP_Header_Access is access all IP_Header;

   --  UDP packet header RFC 768.
   type UDP_Header is record
      Uh_Sport    : Uint16;
      Uh_Dport    : Uint16;
      Uh_Ulen     : Uint16;
      Uh_Sum      : Uint16;
   end record;
   type UDP_Header_Access is access all UDP_Header;

end Net.Headers;
