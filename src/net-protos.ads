-----------------------------------------------------------------------
--  net-protos -- Network protocols
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
package Net.Protos is

   pragma Preelaborate;

   ETHERTYPE_ARP  : constant Uint16 := 16#0806#;
   ETHERTYPE_IP   : constant Uint16 := 16#0800#;
   ETHERTYPE_IPv6 : constant Uint16 := 16#86DD#;

   type Receive_Handler is access
     not null procedure (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                         Packet : in out Net.Buffers.Buffer_Type);

end Net.Protos;
