-----------------------------------------------------------------------
--  receiver -- Ethernet Packet Receiver
--  Copyright (C) 2016-2024 Stephane Carrez
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
with Net.Interfaces;

generic
   Ifnet : in out Net.Interfaces.Ifnet_Type'Class;
   Storage_Size : Positive := 16 * 1024;
   Priority : System.Priority := System.Default_Priority;
package Net.Generic_Receiver is

   type Us_Time is new Natural;

   --  Average, min and max time in microseconds taken to process a packet.
   Avg_Receive_Time : Us_Time := 0 with Atomic;
   Min_Receive_Time : Us_Time := 0 with Atomic;
   Max_Receive_Time : Us_Time := 0 with Atomic;

   --  Start the receiver loop.
   procedure Start;

   --  The task that waits for packets.
   task Controller with
     Storage_Size => Storage_Size,
     Priority => Priority;

end Net.Generic_Receiver;
