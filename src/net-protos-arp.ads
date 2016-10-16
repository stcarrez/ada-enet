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
package Net.Protos.Arp is

   ARPHRD_ETHER     : constant Uint16 := 1;

   ARPOP_REQUEST    : constant Uint16 := 1;
   ARPOP_REPLY      : constant Uint16 := 2;
   ARPOP_REVREQUEST : constant Uint16 := 3;
   ARPOP_REVREPLY   : constant Uint16 := 4;
   ARPOP_INVREQUEST : constant Uint16 := 8;
   ARPOP_INVREPLY   : constant Uint16 := 8;

   type Arp_Status is (ARP_FOUND, ARP_PENDING, ARP_NEEDED, ARP_UNREACHABLE);

   procedure Request (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Source_Ip : in Ip_Addr;
                      Target_Ip : in Ip_Addr;
                      Mac       : in Ether_Addr);

   --  Resolve the target IP address to obtain the associated Ethernet address
   --  from the ARP table.  The Status indicates whether the IP address is
   --  found, or a pending ARP resolution is in progress or it was unreachable.
   procedure Resolve (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Target_Ip : in Ip_Addr;
                      Mac       : out Ether_Addr;
                      Status    : out Arp_Status);

   procedure Receive (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet    : in out Net.Buffers.Buffer_Type);

   --  Update the arp table with the IP address and the associated Ethernet address.
   procedure Update (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                     Target_Ip : in Ip_Addr;
                     Mac       : in Ether_Addr);

end Net.Protos.Arp;
