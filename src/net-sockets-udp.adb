-----------------------------------------------------------------------
--  net-sockets-udp -- UDP socket-like interface
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
with Net.Protos.IPv4;
package body Net.Sockets.Udp is

   procedure Bind (Endpoint : in out Socket;
                   Ifnet    : access Net.Interfaces.Ifnet_Type'Class;
                   Addr     : in Sockaddr_In) is
   begin
      Endpoint.Ifnet  := Ifnet;
      Endpoint.Listen := Addr;
   end Bind;

   procedure Send (Endpoint : in out Socket;
                   To       : in Sockaddr_in;
                   Packet   : in out Net.Buffers.Buffer_Type) is
      Hdr : constant Net.Headers.UDP_Header_Access := Packet.UDP;
   begin
      Hdr.Uh_Dport := Net.Headers.To_Network (To.Port);
      Hdr.Uh_Sport := Net.Headers.To_Network (Endpoint.Listen.Port);
      Hdr.Uh_Sum   := 0;
      Hdr.Uh_Ulen  := Net.Headers.To_Network (Net.Uint16 (Packet.Get_Data_Size));
      Net.Protos.IPv4.Send (Endpoint.Ifnet.all, To.Addr, Packet);
   end Send;

end Net.Sockets.Udp;
