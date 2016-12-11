-----------------------------------------------------------------------
--  net-protos-dispatchers -- Network protocol dispatchers
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
with Net.Headers;
with Net.Buffers;
with Net.Interfaces;
with Net.Protos.IPv4;
with Net.Protos.Arp;
with Net.Protos.Icmp;
with Net.Sockets.Udp;
package body Net.Protos.Dispatchers is

   procedure Default_Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                              Packet : in out Net.Buffers.Buffer_Type);

   Igmp_Receive    : Receive_Handler := Default_Receive'Access;
   Icmp_Receive    : Receive_Handler := Net.Protos.Icmp.Receive'Access;
   Udp_Receive     : Receive_Handler := Net.Sockets.Udp.Input'Access;
   Other_Receive   : Receive_Handler := Default_Receive'Access;

   procedure Default_Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                              Packet : in out Net.Buffers.Buffer_Type) is
   begin
      null;
   end Default_Receive;

   --  ------------------------------
   --  Receive an IPv4 packet and dispatch it according to the protocol.
   --  ------------------------------
   procedure Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet : in out Net.Buffers.Buffer_Type) is
      Ip_Hdr : constant Net.Headers.IP_Header_Access := Packet.IP;
   begin
      case Ip_Hdr.Ip_P is
         when Net.Protos.IPv4.P_ICMP =>
            Icmp_Receive (Ifnet, Packet);

         when Net.Protos.IPv4.P_IGMP =>
            Igmp_Receive (Ifnet, Packet);

         when Net.Protos.IPv4.P_UDP =>
            Udp_Receive (Ifnet, Packet);

         when others =>
            Other_Receive (Ifnet, Packet);

      end case;
   end Receive;

end Net.Protos.Dispatchers;
