-----------------------------------------------------------------------
--  net-protos-dispatchers -- Network protocol dispatchers
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
with Net.Buffers;
with Net.Interfaces;
package Net.Protos.Dispatchers is

   --  Set a protocol handler to deal with a packet of the given protocol when it is received.
   --  Return the previous protocol handler.
   procedure Set_Handler (Proto    : in Net.Uint8;
                          Handler  : in Receive_Handler;
                          Previous : out Receive_Handler);

   --  Receive an IPv4 packet and dispatch it according to the protocol.
   procedure Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet : in out Net.Buffers.Buffer_Type) with
     Pre => not Packet.Is_Null;

end Net.Protos.Dispatchers;
