-----------------------------------------------------------------------
--  net-protos-arp -- ARP Network protocol
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
with Net.Interfaces;
with Net.Buffers;

--  == ARP Protocol ==
--  The <b>Net.Protos.Arp</b> package implements the support for the ARP protocol used for the
--  resolution of IPv4 addresses.  The package maintains a ARP database within an Ada protected
--  object.
--
--  The <b>Resolve</b> procedure is the main entry point for the resolution of the IPv4 address.
--  Given a target IP address, it first looks in the ARP database for the associated Ethernet
--  address.  When the Ethernet address is known, it updates the Ethernet header so that the
--  packet can be sent to the network interface.
--
--  When the Ethernet address is now known, the <b>Resolve</b> procedure puts the packet in a
--  queue and it makes an ARP request.
--
--  The <b>Receive</b> procedure should be called when a ARP packet is received.  It is responsible
--  for replying to ARP requests from other hosts on the network and handling ARP response for
--  our requests.  It updates the ARP database only when we receive a ARP response from one of
--  our ARP query.
--
package Net.Protos.Arp is

   ARPHRD_ETHER     : constant Uint16 := 1;

   ARPOP_REQUEST    : constant Uint16 := 1;
   ARPOP_REPLY      : constant Uint16 := 2;
   ARPOP_REVREQUEST : constant Uint16 := 3;
   ARPOP_REVREPLY   : constant Uint16 := 4;
   ARPOP_INVREQUEST : constant Uint16 := 8;
   ARPOP_INVREPLY   : constant Uint16 := 8;

   type Arp_Status is (ARP_FOUND, ARP_PENDING, ARP_NEEDED, ARP_QUEUE_FULL, ARP_UNREACHABLE);

   procedure Request (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Source_Ip : in Ip_Addr;
                      Target_Ip : in Ip_Addr;
                      Mac       : in Ether_Addr);

   --  Proceed to the ARP database timeouts, cleaning entries and re-sending pending
   --  ARP requests.  The procedure should be called once every second.
   procedure Timeout (Ifnet : in out Net.Interfaces.Ifnet_Type'Class);

   --  Resolve the target IP address to obtain the associated Ethernet address
   --  from the ARP table.  The Status indicates whether the IP address is
   --  found, or a pending ARP resolution is in progress or it was unreachable.
   procedure Resolve (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Target_Ip : in Ip_Addr;
                      Mac       : out Ether_Addr;
                      Packet    : in out Net.Buffers.Buffer_Type;
                      Status    : out Arp_Status);

   procedure Receive (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet    : in out Net.Buffers.Buffer_Type);

   --  Update the arp table with the IP address and the associated Ethernet address.
   procedure Update (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                     Target_Ip : in Ip_Addr;
                     Mac       : in Ether_Addr);

end Net.Protos.Arp;
