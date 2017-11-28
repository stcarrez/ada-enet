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
--  time synchronized with the NTP server.  The NTP client does not maintain the date but allows
--  to retrieve the NTP reference information which together with the Ada monotonic time can
--  be used to get the current date.
--
--  An NTP client is associated with a particular NTP server.  An application can use several
--  NTP client instance to synchronize with several NTP server and then choose the best
--  NTP reference for its date.
--
--  === Initialization ===
--  The NTP client is represented by the <tt>Client</tt> tagged type.  An instance must be
--  declared for the management of the NTP state machine:
--
--    Client : Net.NTP.Client;
--
--  The NTP client is then initialized by giving the network interface and the NTP server to use:
--
--    Ntp_Server : Net.Ip_Addr := ...;
--    ...
--    Client.Initialize (Ifnet'Access, Ntp_Server);
--
--  === Processing ===
--  The NTP synchronisation is an asynchronous process that must be run continuously.
--  The <tt>Process</tt> procedure is responsible for sending the NTP client request to the
--  server on a regular basis.  The <tt>Receive</tt> procedure will be called by the UDP stack
--  when the NTP server response is received.  The NTP reference is computed when a correct
--  NTP server response is received.  The state and NTP reference for the NTP synchronization
--  is maintained by a protected type held by the <tt>Client</tt> tagged type.
--
--  The <tt>Process</tt> procedure should be called to initiate the NTP request to the server
--  and then periodically synchronize with the server.  The operation returns a time in the future
--  that indicates the deadline time for the next call.  It is acceptable to call this operation
--  more often than necessary.
--
--    Ntp_Deadline : Ada.Real_Time.Time;
--    ..
--    Client.Process (Ntp_Deadline);
--
--  === NTP Date ===
--  The NTP reference information is retrieved by using the <tt>Get_Reference</tt> operation
--  which returns the NTP date together with the status and delay information between the client
--  and the server.
--
--    Ref : Net.NTP.NTP_Reference := Client.Get_Reference;
--    Now : Net.NTP.NTP_Timestamp;
--
--  Before using the NTP reference, it is necessary to check the status.  The <tt>SYNCED</tt>
--  and <tt>RESYNC</tt> are the two possible states which indicate a successful synchronization.
--  The current date and time is obtained by the <tt>Get_Time</tt> function which uses the
--  NTP reference and the Ada monotonic time to return the current date (in NTP format).
--
--    if Ref.Status in Net.NTP.SYNCED | Net.NTP.RESYNC then
--       Now := Net.NTP.Get_Time (Ref);
--    end if;
--
--  The NTP date is a GMT time whose first epoch date is January 1st 1900.
package Net.NTP is

   --  The NTP UDP port number.
   NTP_PORT : constant Net.Uint16 := 123;

   ONE_SEC  : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   ONE_USEC : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Microseconds (1);

   --  The NTP reference date: 1970 - 1900 seconds.  */
   JAN_1970 : constant Net.Uint32 := 2208988800;

   --  The NTP client status.
   type Status_Type is (NOSERVER, INIT, WAITING, SYNCED, RESYNC, TIMEOUT);

   --  The NTP timestamp as defined by RFC 5905.  The NTP epoch is Jan 1st 1900 and
   --  NTP subseconds use the full 32-bit range.  When bit 31 of the seconds is cleared,
   --  we consider this as the second epoch which starts in 2036.
   type NTP_Timestamp is record
      Seconds     : Net.Uint32 := 0;
      Sub_Seconds : Net.Uint32 := 0;
   end record;

   --  Add a time span to the NTP timestamp.
   function "+" (Left  : in NTP_Timestamp;
                 Right : in Ada.Real_Time.Time_Span) return NTP_Timestamp;

   --  The NTP reference indicates the NTP synchronisation with the NTP server.
   --  The reference indicates the NTP time at a given point in the past when the NTP
   --  synchronization is obtained.  When several NTP servers are used, the NTP references
   --  should be compared and the NTP server with the lowest <tt>Delta_Time</tt> should be
   --  used.
   --
   --  The current date is obtained with the following forumla:
   --
   --    Date := Offset_Time + (Ada.Realtime.Clock - Offset_Ref)
   type NTP_Reference is record
      Status        : Status_Type := NOSERVER;
      Offset_Time   : NTP_Timestamp;
      Offset_Ref    : Ada.Real_Time.Time;
      Delta_Time    : Ada.Real_Time.Time_Span;
   end record;

   --  Get the current date from the Ada monotonic time and the NTP reference.
   function Get_Time (Ref : in NTP_Reference) return NTP_Timestamp;

   type Client is new Net.Sockets.Udp.Socket with private;

   --  Get the NTP client status.
   function Get_Status (Request : in Client) return Status_Type;

   --  Get the NTP time.
   function Get_Time (Request : in out Client) return NTP_Timestamp;

   --  Get the delta time between the NTP server and us.
   function Get_Delta (Request : in out Client) return Integer_64;

   --  Get the NTP reference information.
   function Get_Reference (Request : in out Client) return NTP_Reference;

   --  Initialize the NTP client to use the given NTP server.
   procedure Initialize (Request : access Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                         Server  : in Net.Ip_Addr;
                         Port    : in Net.Uint16 := NTP_PORT);

   --  Process the NTP client.
   --  Return in <tt>Next_Call</tt> the deadline time for the next call.
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time);

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

      --  Get the NTP reference information.
      function Get_Reference return NTP_Reference;

      --  Get the current NTP timestamp with the corresponding monitonic time.
      procedure Get_Timestamp (Time : out NTP_Timestamp;
                               Now  : out Ada.Real_Time.Time);

      --  Set the status time.
      procedure Set_Status (Value : in Status_Type);

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
