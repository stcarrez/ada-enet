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
with Net.Headers;

package body Net.NTP is

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   --  ------------------------------
   --  Add a time span to the NTP timestamp.
   --  ------------------------------
   function "+" (Left  : in NTP_Timestamp;
                 Right : in Ada.Real_Time.Time_Span) return NTP_Timestamp is
      N      : Unsigned_64;
      Result : NTP_Timestamp;
      Sec    : constant Integer := Right / ONE_SEC;
      Usec   : constant Integer := (Right - Ada.Real_Time.Seconds (Sec)) / ONE_USEC;
   begin
      Result.Seconds := Left.Seconds + Net.Uint32 (Sec);

      --  Convert the time_span to NTP subseconds.
      --  First convert to microseconds and then to sub-seconds by using 64-bit values.
      N := Shift_Left (Unsigned_64 (Usec), 32) / 1_000_000;
      if Left.Sub_Seconds > Net.Uint32'Last - Net.Uint32 (N) then
         Result.Sub_Seconds := Net.Uint32 (N) - (Net.Uint32'Last - Left.Sub_Seconds + 1);
         Result.Seconds := Result.Seconds + 1;
      else
         Result.Sub_Seconds := Left.Sub_Seconds + Net.Uint32 (N);
      end if;
      return Result;
   end "+";

   --  ------------------------------
   --  Get the current date from the Ada monotonic time and the NTP reference.
   --  ------------------------------
   function Get_Time (Ref : in NTP_Reference) return NTP_Timestamp is
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Result : NTP_Timestamp;
   begin
      Result := Ref.Offset_Time + (Now - Ref.Offset_Ref);
      Result.Seconds := Result.Seconds - JAN_1970;
      return Result;
   end Get_Time;

   --  ------------------------------
   --  Get the NTP client status.
   --  ------------------------------
   function Get_Status (Request : in Client) return Status_Type is
   begin
      return Request.State.Get_Status;
   end Get_Status;

   --  ------------------------------
   --  Get the NTP time.
   --  ------------------------------
   function Get_Time (Request : in out Client) return NTP_Timestamp is
      Result : NTP_Timestamp;
      Clock  : Ada.Real_Time.Time;
   begin
      Request.State.Get_Timestamp (Result, Clock);
      return Result;
   end Get_Time;

   --  ------------------------------
   --  Get the delta time between the NTP server and us.
   --  ------------------------------
   function Get_Delta (Request : in out Client) return Integer_64 is
   begin
      return Request.State.Get_Delta;
   end Get_Delta;

   --  ------------------------------
   --  Get the NTP reference information.
   --  ------------------------------
   function Get_Reference (Request : in out Client) return NTP_Reference is
   begin
      return Request.State.Get_Reference;
   end Get_Reference;

   --  ------------------------------
   --  Initialize the NTP client to use the given NTP server.
   --  ------------------------------
   procedure Initialize (Request : access Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                         Server  : in Net.Ip_Addr;
                         Port    : in Net.Uint16 := Net.NTP.NTP_PORT) is
      Addr : Net.Sockets.Sockaddr_In;
   begin
      Request.Server := Server;
      Addr.Port := Net.Headers.To_Network (Port);
      Addr.Addr := Ifnet.Ip;
      Request.Bind (Ifnet => Ifnet,
                    Addr  => Addr);
      Request.State.Set_Status (INIT);
   end Initialize;

   --  ------------------------------
   --  Process the NTP client.
   --  Return in <tt>Next_Call</tt> the deadline time for the next call.
   --  ------------------------------
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time) is
      Buf    : Net.Buffers.Buffer_Type;
      Status : Error_Code;
      To     : Net.Sockets.Sockaddr_In;
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      if Now < Request.Deadline then
         Next_Call := Request.Deadline;
         return;
      end if;
      if Request.Get_Status = NOSERVER then
         Next_Call := Now + Ada.Real_Time.Seconds (1);
         return;
      end if;
      Request.Deadline := Now + Ada.Real_Time.Seconds (8);
      Next_Call := Request.Deadline;
      Net.Buffers.Allocate (Buf);
      Buf.Set_Type (Net.Buffers.UDP_PACKET);

      --  NTP flags: clock unsynchronized, NTP version 4, Mode client.
      Buf.Put_Uint8 (16#e3#);

      --  Peer clock stratum: 0 for the client.
      Buf.Put_Uint8 (0);

      --  Peer polling interval: 6 = 64 seconds.
      Buf.Put_Uint8 (16#6#);

      --  Peer clock precision: 0 sec.
      Buf.Put_Uint8 (16#e9#);

      --  Root delay
      Buf.Put_Uint32 (0);

      --  Root dispersion
      Buf.Put_Uint32 (0);
      Buf.Put_Uint8 (16#49#);
      Buf.Put_Uint8 (16#4e#);
      Buf.Put_Uint8 (16#49#);
      Buf.Put_Uint8 (16#54#);
      Request.State.Put_Timestamp (Buf);

      To.Port := Net.Headers.To_Network (NTP_PORT);
      To.Addr := Request.Server;
      Request.Send (To, Buf, Status);
   end Process;

   --  ------------------------------
   --  Receive the NTP response from the NTP server and update the NTP state machine.
   --  ------------------------------
   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      pragma Unreferenced (From);

      Flags      : Net.Uint8;
      Stratum    : Net.Uint8;
      Interval   : Net.Uint8;
      Precision  : Net.Uint8;
      Root_Delay : Net.Uint32;
      Dispersion : Net.Uint32;
      Ref_Id     : Net.Uint32;
      pragma Unreferenced (Stratum, Interval, Precision, Root_Delay, Dispersion, Ref_Id);
   begin
      if Packet.Get_Length < 56 then
         return;
      end if;
      Flags := Packet.Get_Uint8;

      --  Accept version 4 or version 3 server.
      if Flags /= 16#24# and Flags /= 16#1c# then
         return;
      end if;
      Stratum    := Packet.Get_Uint8;
      Interval   := Packet.Get_Uint8;
      Precision  := Packet.Get_Uint8;
      Root_Delay := Packet.Get_Uint32;
      Dispersion := Packet.Get_Uint32;
      Ref_Id     := Packet.Get_Uint32;
      Request.State.Extract_Timestamp (Packet);
   end Receive;

   function To_Unsigned_64 (T : in NTP_Timestamp) return Unsigned_64;
   function "-" (Left, Right : in NTP_Timestamp) return Integer_64;

   function To_Unsigned_64 (T : in NTP_Timestamp) return Unsigned_64 is
   begin
      return Unsigned_64 (T.Sub_Seconds)
        + Shift_Left (Unsigned_64 (T.Seconds), 32);
   end To_Unsigned_64;

   function "-" (Left, Right : in NTP_Timestamp) return Integer_64 is
      T1 : constant Unsigned_64 := To_Unsigned_64 (Left);
      T2 : constant Unsigned_64 := To_Unsigned_64 (Right);
   begin
      if T1 > T2 then
         return Integer_64 (T1 - T2);
      else
         return -Integer_64 (T2 - T2);
      end if;
   end "-";

   protected body Machine is

      --  ------------------------------
      --  Get the NTP status.
      --  ------------------------------
      function Get_Status return Status_Type is
      begin
         return Status;
      end Get_Status;

      --  ------------------------------
      --  Set the status time.
      --  ------------------------------
      procedure Set_Status (Value : in Status_Type) is
      begin
         Status := Value;
         Offset_Ref := Ada.Real_Time.Clock;
      end Set_Status;

      --  ------------------------------
      --  Get the delta time between the NTP server and us.
      --  ------------------------------
      function Get_Delta return Integer_64 is
      begin
         return Delta_Time;
      end Get_Delta;

      --  ------------------------------
      --  Get the NTP reference information.
      --  ------------------------------
      function Get_Reference return NTP_Reference is
         Result : NTP_Reference;
         Secs   : Integer;
         Usec   : Integer;
      begin
         Result.Status := Status;
         Result.Offset_Time := Offset_Time;
         Result.Offset_Ref  := Offset_Ref;
         if Result.Status in SYNCED | RESYNC then
            Secs := Integer (Shift_Right (Net.Uint64 (Delta_Time), 32));
            Usec := Integer (Shift_Right ((Net.Uint64 (Delta_Time) and 16#0ffffffff#) * 1_000_000, 32));
            Result.Delta_Time := Ada.Real_Time.Microseconds (Usec) + Ada.Real_Time.Seconds (Secs);
         else
            Result.Delta_Time := Ada.Real_Time.Time_Span_Last;
         end if;
         return Result;
      end Get_Reference;

      --  ------------------------------
      --  Get the current NTP timestamp with the corresponding monitonic time.
      --  ------------------------------
      procedure Get_Timestamp (Time : out NTP_Timestamp;
                               Now  : out Ada.Real_Time.Time) is
      begin
         Now  := Ada.Real_Time.Clock;
         Time := Offset_Time + (Now - Offset_Ref);
      end Get_Timestamp;

      --  ------------------------------
      --  Insert in the packet the timestamp references for the NTP client packet.
      --  ------------------------------
      procedure Put_Timestamp (Buf : in out Net.Buffers.Buffer_Type) is
         Now   : NTP_Timestamp;
         Clock : Ada.Real_Time.Time;
      begin
         Buf.Put_Uint32 (0);
         Buf.Put_Uint32 (0);
         Buf.Put_Uint32 (Orig_Time.Seconds);
         Buf.Put_Uint32 (Orig_Time.Sub_Seconds);
         Buf.Put_Uint32 (Rec_Time.Seconds);
         Buf.Put_Uint32 (Rec_Time.Sub_Seconds);
         Get_Timestamp (Now, Clock);
         Buf.Put_Uint32 (Now.Seconds);
         Buf.Put_Uint32 (Now.Sub_Seconds);
         Transmit_Time := Now;

         --  Update status to indicate we are resynchronizing or waiting for synchronization.
         if Status = SYNCED then
            Status := RESYNC;
         elsif Status = RESYNC then
            Status := TIMEOUT;
         else
            Status := WAITING;
         end if;
      end Put_Timestamp;

      --  ------------------------------
      --  Extract the timestamp from the NTP server response and update the reference time.
      --  ------------------------------
      procedure Extract_Timestamp (Buf : in out Net.Buffers.Buffer_Type) is
         OTime : NTP_Timestamp;
         RTime : NTP_Timestamp;
         Now   : NTP_Timestamp;
         Rec   : NTP_Timestamp;
         Clock : Ada.Real_Time.Time;
         pragma Unreferenced (RTime);
      begin
         Get_Timestamp (Now, Clock);
         RTime.Seconds     := Buf.Get_Uint32;
         RTime.Sub_Seconds := Buf.Get_Uint32;
         OTime.Seconds     := Buf.Get_Uint32;
         OTime.Sub_Seconds := Buf.Get_Uint32;

         --  Check for bogus packet (RFC 5905, 8.  On-Wire Protocol).
         if OTime /= Transmit_Time then
            return;
         end if;
         Transmit_Time.Seconds     := 0;
         Transmit_Time.Sub_Seconds := 0;
         Rec.Seconds       := Buf.Get_Uint32;
         Rec.Sub_Seconds   := Buf.Get_Uint32;
         Orig_Time.Seconds := Buf.Get_Uint32;
         Orig_Time.Sub_Seconds := Buf.Get_Uint32;
         Rec_Time  := Now;
         Offset_Time := Orig_Time;
         Offset_Ref  := Clock;

         --  (T4 - T1) - (T3 - T2)
         Delta_Time := (Now - OTime) - (Orig_Time - Rec);
         if Delta_Time < 0 then
            Delta_Time := 0;
         end if;

         --  We are synchronized now.
         Status := SYNCED;
      end Extract_Timestamp;

   end Machine;

end Net.NTP;
