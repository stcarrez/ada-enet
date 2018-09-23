-----------------------------------------------------------------------
--  net-protos-icmp -- ICMP v4 Network protocol
--  Copyright (C) 2016, 2018 Stephane Carrez
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
package Net.Protos.Icmp is

   --  Send a ICMP echo request packet to the target IP.  The ICMP header is
   --  initialized with the given sequence and identifier so that ICMP reply
   --  can be identified.
   procedure Echo_Request (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                           Target_Ip : in Ip_Addr;
                           Packet    : in out Net.Buffers.Buffer_Type;
                           Seq       : in Net.Uint16;
                           Ident     : in Net.Uint16;
                           Status    : out Error_Code) with
     Pre => not Packet.Is_Null,
     Post => Packet.Is_Null;

   --  Receive and handle an ICMP packet.
   procedure Receive (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet    : in out Net.Buffers.Buffer_Type) with
     Pre => not Packet.Is_Null,
     Post => Packet.Is_Null;

end Net.Protos.Icmp;
