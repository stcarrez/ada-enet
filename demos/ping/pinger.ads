-----------------------------------------------------------------------
--  pinger -- Ping hosts
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
with Net;
with Net.Interfaces;
with Net.Buffers;
package Pinger is

   --  Maximum number of host we can ping.
   MAX_PING_HOST : constant Positive := 8;

   NO_IP : constant Net.Ip_Addr := (0, 0, 0, 0);

   --  Information about a ping request that we sent.
   type Ping_Info is record
      Ip       : Net.Ip_Addr := NO_IP;
      Seq      : Net.Uint16  := 0;
      Received : Natural     := 0;
   end record;

   type Ping_Info_Array is array (Natural range <>) of Ping_Info;

   --  Get the list of hosts with their ping counters.
   function Get_Hosts return Ping_Info_Array;

   --  Add the host to ping list.
   procedure Add_Host (Ip : in Net.Ip_Addr);

   --  Send the ICMP echo request to each host.
   procedure Do_Ping;

   procedure Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet : in out Net.Buffers.Buffer_Type);

end Pinger;
