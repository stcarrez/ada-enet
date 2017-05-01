-----------------------------------------------------------------------
--  net-ntp -- NTP Network utilities
--  Copyright (C) 2017 Stephane Carrez
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
with Ada.Real_Time;
with Interfaces; use Interfaces;
with Net.Interfaces;
with Net.Buffers;
with Net.Sockets.Udp;

--  == NTP Client ==
--  The NTP client is used to retrieve the time by using the NTP protocol and keep the local
--  time synchronized with the NTP server.
--
--  === Initialization ===
--  The NTP client is represented by the <tt>Client</tt> tagged type.  An instance must be
--  declared for the management of the NTP state machine:
--
--    Client : Net.NTP.Client;
--
package Net.NTP is

   --  The NTP UDP port number.
   NTP_PORT : constant Net.Uint16 := 123;

   type NTP_Timestamp is record
      Seconds     : Net.Uint32 := 0;
      Sub_Seconds : Net.Uint32 := 0;
   end record;

   --  The NTP client status.
   type Status_Type is (NOSERVER, INIT, WAITING, SYNCED, RESYNC);

   type Client is new Net.Sockets.Udp.Socket with private;

   --  Get the NTP client status.
   function Get_Status (Request : in Client) return Status_Type;

   --  Get the NTP time.
   function Get_Time (Request : in out Client) return NTP_Timestamp;

   --  Get the delta time between the NTP server and us.
   function Get_Delta (Request : in out Client) return Integer_64;

   --  Initialize the NTP client to use the given NTP server.
   procedure Initialize (Request : access Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                         Server  : in Net.Ip_Addr);

   --  Process the NTP client.
   --  Return in <tt>Next_Call</tt> the maximum time to wait before the next call.
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time_Span);

   --  Receive the NTP response from the NTP server and update the NTP state machine.
   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

private

   protected type Machine is
      --  Get the NTP status.
      function Get_Status return Status_Type;

      --  Get the delta time between the NTP server and us.
      function Get_Delta return Integer_64;

      --  Get the current NTP timestamp with the corresponding monitonic time.
      procedure Get_Timestamp (Time : out NTP_Timestamp;
                               Now  : out Ada.Real_Time.Time);

      --  Extract the timestamp from the NTP server response and update the reference time.
      procedure Extract_Timestamp (Buf : in out Net.Buffers.Buffer_Type);

      --  Insert in the packet the timestamp references for the NTP client packet.
      procedure Put_Timestamp (Buf : in out Net.Buffers.Buffer_Type);

   private
      Status        : Status_Type := NOSERVER;
      Ref_Time      : NTP_Timestamp;
      Orig_Time     : NTP_Timestamp;
      Rec_Time      : NTP_Timestamp;
      Offset_Time   : NTP_Timestamp;
      Transmit_Time : NTP_Timestamp;
      Offset_Ref    : Ada.Real_Time.Time;
      Delta_Time    : Integer_64;
   end Machine;

   type Client is new Net.Sockets.Udp.Socket with record
      Server   : Net.Ip_Addr := (0, 0, 0, 0);
      Deadline : Ada.Real_Time.Time;
      State    : Machine;
   end record;

end Net.NTP;
