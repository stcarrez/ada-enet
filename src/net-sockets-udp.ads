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
with Net.Buffers;
with Net.Interfaces;
package Net.Sockets.Udp is

   type Socket is abstract tagged limited private;

   procedure Bind (Endpoint : access Socket'Class;
                   Ifnet    : access Net.Interfaces.Ifnet_Type'Class;
                   Addr     : in Sockaddr_In);

   --  Send the UDP packet to the destination IP and port.
   procedure Send (Endpoint : in out Socket;
                   To       : in Sockaddr_In;
                   Packet   : in out Net.Buffers.Buffer_Type);

   procedure Receive (Endpoint : in out Socket;
                      From     : in Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is abstract;

   --  Input a UDP packet and dispatch it to the associated UDP socket.
   procedure Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                    Packet : in out Net.Buffers.Buffer_Type);

private

   type Socket is abstract tagged limited record
      Next   : access Socket'Class;
      Listen : Sockaddr_In;
      Ifnet  : access Net.Interfaces.Ifnet_Type'Class;
   end record;

end Net.Sockets.Udp;
