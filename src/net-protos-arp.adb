-----------------------------------------------------------------------
--  net-protos-arp -- ARP Network protocol
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
with Ada.Real_Time;

with Net.Headers;
package body Net.Protos.Arp is

   use type Ada.Real_Time.Time;

   Broadcast_Mac : constant Ether_Addr := (others => 16#ff#);

   Arp_Retry_Timeout       : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   Arp_Entry_Timeout       : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (30);
   Arp_Unreachable_Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (120);
   Arp_Stale_Timeout       : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (120);

   --  The ARP table index uses the last byte of the IP address.  We assume our network is
   --  a /24 which means we can have 253 valid IP addresses (0 and 255 are excluded).
   subtype Arp_Index is Uint8 range 1 .. 254;

   --  Maximum number of ARP entries we can remember.  We could increase to 253 but most
   --  application will only send packets to a small number of hosts.
   ARP_MAX_ENTRIES   : constant Positive := 32;

   --  Accept to queue at most 30 packets.
   QUEUE_LIMIT       : constant Natural := 30;

   --  The maximum number of packets which can be queued for each entry.
   QUEUE_ENTRY_LIMIT : constant Uint8 := 3;

   ARP_MAX_RETRY : constant Positive := 15;


   type Arp_Entry;
   type Arp_Entry_Access is access all Arp_Entry;

   type Arp_Entry is record
      Ether       : Ether_Addr;
      Expire      : Ada.Real_Time.Time;
      Queue       : Net.Buffers.Buffer_List;
      Retry       : Natural := 0;
      Index       : Arp_Index := Arp_Index'First;
      Queue_Size  : Uint8 := 0;
      Valid       : Boolean := False;
      Unreachable : Boolean := False;
      Pending     : Boolean := False;
      Stale       : Boolean := False;
      Free        : Boolean := True;
   end record;

   type Arp_Entry_Table is array (1 .. ARP_MAX_ENTRIES) of aliased Arp_Entry;
   type Arp_Table is array (Arp_Index) of Arp_Entry_Access;
   type Arp_Refresh is array (1 .. ARP_MAX_ENTRIES) of Arp_Index;

   --  ARP database.
   --  To make it simple and avoid dynamic memory allocation, we maintain a maximum of 256
   --  entries which correspond to a class C network.  We only keep entries that are for our
   --  network.  The lookup is in O(1).
   protected Database is

      procedure Timeout (Ifnet : in out Net.Interfaces.Ifnet_Type'Class;
                         Refresh : out Arp_Refresh;
                         Count   : out Natural);

      procedure Resolve (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                         Ip     : in Ip_Addr;
                         Mac    : out Ether_Addr;
                         Packet : in out Net.Buffers.Buffer_Type;
                         Result : out Arp_Status);

      procedure Update (Ip   : in Ip_Addr;
                        Mac  : in Ether_Addr;
                        List : out Net.Buffers.Buffer_List);

   private
      Entries    : Arp_Entry_Table;
      Table      : Arp_Table := (others => null);
      Queue_Size : Natural := 0;
   end Database;


   protected body Database is

      procedure Drop_Queue (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                            Rt     : in Arp_Entry_Access) is
         pragma Unreferenced (Ifnet);
      begin
         if Rt.Queue_Size > 0 then
            Queue_Size := Queue_Size - Natural (Rt.Queue_Size);
            Rt.Queue_Size := 0;
            Net.Buffers.Release (Rt.Queue);
         end if;
      end Drop_Queue;

      procedure Timeout (Ifnet   : in out Net.Interfaces.Ifnet_Type'Class;
                         Refresh : out Arp_Refresh;
                         Count   : out Natural) is
         Now       : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Count := 0;
         for I in Entries'Range loop
            if not Entries (I).Free and then Entries (I).Expire < Now then
               if Entries (I).Valid then
                  Entries (I).Valid := False;
                  Entries (I).Stale := True;
                  Entries (I).Expire := Now + Arp_Stale_Timeout;

               elsif Entries (I).Stale then
                  Entries (I).Free := True;
                  Table (Entries (I).Index) := null;

               elsif Entries (I).Retry > 5 then
                  Entries (I).Unreachable := True;
                  Entries (I).Expire := Now + Arp_Unreachable_Timeout;
                  Entries (I).Retry := 0;
                  Drop_Queue (Ifnet, Entries (I)'Access);

               else
                  Count := Count + 1;
                  Refresh (Count) := Entries (I).Index;
                  Entries (I).Retry := Entries (I).Retry + 1;
                  Entries (I).Expire := Now + Arp_Retry_Timeout;
               end if;
            end if;
         end loop;
      end Timeout;

      procedure Resolve (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                         Ip     : in Ip_Addr;
                         Mac    : out Ether_Addr;
                         Packet : in out Net.Buffers.Buffer_Type;
                         Result : out Arp_Status) is
         Index : constant Arp_Index := Ip (Ip'Last);
         Rt    : Arp_Entry_Access := Table (Index);
         Now   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         if Rt = null then
            for I in Entries'Range loop
               if Entries (I).Free then
                  Rt := Entries (I)'Access;
                  Rt.Free := False;
                  Rt.Index := Index;
                  Table (Index) := Rt;
                  exit;
               end if;
            end loop;
            if Rt = null then
               Result := ARP_QUEUE_FULL;
               return;
            end if;
         end if;
         if Rt.Valid and then Now < Rt.Expire then
            Mac := Rt.Ether;
            Result := ARP_FOUND;

         elsif Rt.Unreachable and then Now < Rt.Expire then
            Result := ARP_UNREACHABLE;

            --  Send the first ARP request for the target IP resolution.
         elsif not Rt.Pending then
            Rt.Pending := True;
            Rt.Retry   := 1;
            Rt.Stale   := False;
            Rt.Expire  := Now + Arp_Retry_Timeout;
            Result := ARP_NEEDED;

         elsif Rt.Expire < Now then
            if Rt.Retry > ARP_MAX_RETRY then
               Rt.Unreachable := True;
               Rt.Expire := Now + Arp_Unreachable_Timeout;
               Rt.Pending := False;
               Result := ARP_UNREACHABLE;
               Drop_Queue (Ifnet, Rt);
            else
               Rt.Retry := Rt.Retry + 1;
               Rt.Expire := Now + Arp_Retry_Timeout;
               Result := ARP_NEEDED;
            end if;
         else
            Result := ARP_PENDING;
         end if;

         --  Queue the packet unless the queue is full.
         if (Result = ARP_PENDING or Result = ARP_NEEDED) and then not Packet.Is_Null then
            if Queue_Size < QUEUE_LIMIT and Rt.Queue_Size < QUEUE_ENTRY_LIMIT then
               Queue_Size := Queue_Size + 1;
               Net.Buffers.Insert (Rt.Queue, Packet);
               Rt.Queue_Size := Rt.Queue_Size + 1;
            else
               Result := ARP_QUEUE_FULL;
            end if;
         end if;
      end Resolve;

      procedure Update (Ip   : in Ip_Addr;
                        Mac  : in Ether_Addr;
                        List : out Net.Buffers.Buffer_List) is
         Rt    : constant Arp_Entry_Access := Table (Ip (Ip'Last));
      begin
         --  We may receive a ARP response without having a valid arp entry in our table.
         --  This could happen when packets are forged (ARP poisoning) or when we dropped
         --  the arp entry before we received any ARP response.
         if Rt /= null then
            Rt.Ether := Mac;
            Rt.Valid := True;
            Rt.Unreachable := False;
            Rt.Pending := False;
            Rt.Stale   := False;
            Rt.Expire := Ada.Real_Time.Clock + Arp_Entry_Timeout;

            --  If we have some packets waiting for the ARP resolution, return the packet list.
            if Rt.Queue_Size > 0 then
               Net.Buffers.Transfer (List, Rt.Queue);
               Queue_Size := Queue_Size - Natural (Rt.Queue_Size);
               Rt.Queue_Size := 0;
            end if;
         end if;
      end Update;

   end Database;

   --  ------------------------------
   --  Proceed to the ARP database timeouts, cleaning entries and re-sending pending
   --  ARP requests.  The procedure should be called once every second.
   --  ------------------------------
   procedure Timeout (Ifnet : in out Net.Interfaces.Ifnet_Type'Class) is
      Refresh : Arp_Refresh;
      Count   : Natural;
      Ip      : Net.Ip_Addr;
   begin
      Database.Timeout (Ifnet, Refresh, Count);
      for I in 1 .. Count loop
         Ip := Ifnet.Ip;
         Ip (Ip'Last) := Refresh (I);
         Request (Ifnet, Ifnet.Ip, Ip, Ifnet.Mac);
      end loop;
   end Timeout;

   --  ------------------------------
   --  Resolve the target IP address to obtain the associated Ethernet address
   --  from the ARP table.  The Status indicates whether the IP address is
   --  found, or a pending ARP resolution is in progress or it was unreachable.
   --  ------------------------------
   procedure Resolve (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Target_Ip : in Ip_Addr;
                      Mac       : out Ether_Addr;
                      Packet    : in out Net.Buffers.Buffer_Type;
                      Status    : out Arp_Status) is
   begin
      Database.Resolve (Ifnet, Target_Ip, Mac, Packet, Status);
      if Status = ARP_NEEDED then
         Request (Ifnet, Ifnet.Ip, Target_Ip, Ifnet.Mac);
      end if;
   end Resolve;

   --  ------------------------------
   --  Update the arp table with the IP address and the associated Ethernet address.
   --  ------------------------------
   procedure Update (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                     Target_Ip : in Ip_Addr;
                     Mac       : in Ether_Addr) is
      Waiting : Net.Buffers.Buffer_List;
      Ether   : Net.Headers.Ether_Header_Access;
      Packet  : Net.Buffers.Buffer_Type;
   begin
      Database.Update (Target_Ip, Mac, Waiting);
      while not Net.Buffers.Is_Empty (Waiting) loop
         Net.Buffers.Peek (Waiting, Packet);
         Ether := Packet.Ethernet;
         Ether.Ether_Dhost := Mac;
         Ifnet.Send (Packet);
      end loop;
   end Update;

   procedure Request (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Source_Ip : in Ip_Addr;
                      Target_Ip : in Ip_Addr;
                      Mac       : in Ether_Addr) is
      Buf : Net.Buffers.Buffer_Type;
      Req : Net.Headers.Arp_Packet_Access;
   begin
      Net.Buffers.Allocate (Buf);
      if Buf.Is_Null then
         return;
      end if;
      Req := Buf.Arp;
      Req.Ethernet.Ether_Dhost := Broadcast_Mac;
      Req.Ethernet.Ether_Shost := Mac;
      Req.Ethernet.Ether_Type  := Net.Headers.To_Network (ETHERTYPE_ARP);
      Req.Arp.Ea_Hdr.Ar_Hdr := Net.Headers.To_Network (ARPOP_REQUEST);
      Req.Arp.Ea_Hdr.Ar_Pro := Net.Headers.To_Network (ETHERTYPE_IP);
      Req.Arp.Ea_Hdr.Ar_Hln := Mac'Length;
      Req.Arp.Ea_Hdr.Ar_Pln := Source_Ip'Length;
      Req.Arp.Ea_Hdr.Ar_Op  := Net.Headers.To_Network (ARPOP_REQUEST);
      Req.Arp.Arp_Sha := Mac;
      Req.Arp.Arp_Spa := Source_Ip;
      Req.Arp.Arp_Tha := (others => 0);
      Req.Arp.Arp_Tpa := Target_Ip;
      Buf.Set_Length ((Req.all'Size) / 8);
      Ifnet.Send (Buf);
   end Request;

   procedure Receive (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet : in out Net.Buffers.Buffer_Type) is
      Req : constant Net.Headers.Arp_Packet_Access := Packet.Arp;
   begin
      --  Check for valid hardware length, protocol length, hardware type and protocol type.
      if Req.Arp.Ea_Hdr.Ar_Hln /= Ifnet.Mac'Length or Req.Arp.Ea_Hdr.Ar_Pln /= Ifnet.Ip'Length
        or Req.Arp.Ea_Hdr.Ar_Hdr /= Net.Headers.To_Network (ARPOP_REQUEST)
        or Req.Arp.Ea_Hdr.Ar_Pro /= Net.Headers.To_Network (ETHERTYPE_IP)
      then
         Ifnet.Rx_Stats.Ignored := Ifnet.Rx_Stats.Ignored + 1;
         return;
      end if;

      case Net.Headers.To_Host (Req.Arp.Ea_Hdr.Ar_Op) is
         when ARPOP_REQUEST =>
            --  This ARP request is for our IP address.
            --  Send the corresponding ARP reply with our Ethernet address.
            if Req.Arp.Arp_Tpa = Ifnet.Ip then
               Req.Ethernet.Ether_Dhost := Req.Arp.Arp_Sha;
               Req.Ethernet.Ether_Shost := Ifnet.Mac;
               Req.Arp.Ea_Hdr.Ar_Op  := Net.Headers.To_Network (ARPOP_REPLY);
               Req.Arp.Arp_Tpa := Req.Arp.Arp_Spa;
               Req.Arp.Arp_Tha := Req.Arp.Arp_Sha;
               Req.Arp.Arp_Sha := Ifnet.Mac;
               Req.Arp.Arp_Spa := Ifnet.Ip;
               Ifnet.Send (Packet);
            end if;

         when ARPOP_REPLY =>
            if Req.Arp.Arp_Tpa = Ifnet.Ip and Req.Arp.Arp_Tha = Ifnet.Mac then
               Update (Ifnet, Req.Arp.Arp_Spa, Req.Arp.Arp_Sha);
            end if;

         when others =>
            Ifnet.Rx_Stats.Ignored := Ifnet.Rx_Stats.Ignored + 1;

      end case;
   end Receive;

end Net.Protos.Arp;
