-----------------------------------------------------------------------
--  receiver -- Ethernet Packet Receiver
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
with System;
with Net.Interfaces.STM32;
with Net.DNS;
with Net.DHCP;
package Receiver is

   --  The Ethernet interface driver.
   Ifnet     : aliased Net.Interfaces.STM32.STM32_Ifnet;

   type Query_Array is array (1 .. 30) of aliased Net.DNS.Query;

   Queries : Query_Array;

   Dhcp    : aliased Net.DHCP.Client;

   --  The task that waits for packets.
   task Controller with
     Storage_Size => (16 * 1024),
     Priority => System.Default_Priority;

end Receiver;
