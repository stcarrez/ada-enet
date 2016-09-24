-----------------------------------------------------------------------
--  net-protos-Ipv4 -- IPv4 Network protocol
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
package Net.Protos.IPv4 is

   P_ICMP : constant Net.Uint8 := 1;
   P_IGMP : constant Net.Uint8 := 2;
   P_TCP  : constant Net.Uint8 := 6;
   P_UDP  : constant Net.Uint8 := 17;

   procedure Send (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                   Target_Ip : in Ip_Addr;
                   Packet    : in out Net.Buffers.Buffer_Type);

end Net.Protos.IPv4;
