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

   type Arp_Index is new Uint8;

   --  Accept to queue at most 30 packets.
   QUEUE_LIMIT : constant Natural := 30;

   BAD_INDEX : constant Arp_Index := 255;

   ARP_MAX_RETRY : constant Positive := 15;

   type Arp_Entry is record
      Ether       : Ether_Addr;
      Expire      : Ada.Real_Time.Time;
      Queue       : Net.Buffers.Buffer_List;
      Queue_Size  : Natural := 0;
      Retry       : Natural := 0;
      Valid       : Boolean := False;
      Unreachable : Boolean := False;
      Pending     : Boolean := False;
   end record;

   type Arp_Table is array (Arp_Index) of Arp_Entry;
   type Arp_Index_Table is array (Uint8) of Arp_Index;

   --  ARP database.
   --  To make it simple and avoid dynamic memory allocation, we maintain a maximum of 256
   --  entries which correspond to a class C network.  We only keep entries that are for our
   --  network.  The lookup is in O(1).
   protected Database is

      procedure Timeout (Ifnet : in out Net.Interfaces.Ifnet_Type'Class);

      procedure Resolve (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                         Ip     : in Ip_Addr;
                         Mac    : out Ether_Addr;
                         Packet : in out Net.Buffers.Buffer_Type;
                         Result : out Arp_Status);

      procedure Update (Ip   : in Ip_Addr;
                        Mac  : in Ether_Addr;
                        List : out Net.Buffers.Buffer_List);

   private
      Table      : Arp_Table;
      Indexes    : Arp_Index_Table := (others => BAD_INDEX);
      Last_Index : Uint8 := 0;
      Queue_Size : Natural := 0;
   end Database;


   protected body Database is

      procedure Timeout (Ifnet : in out Net.Interfaces.Ifnet_Type'Class) is
         Now       : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Target_Ip : Ip_Addr := Ifnet.Ip;
         Index     : Arp_Index;
      begin
         for I in 0 .. Last_Index loop
            Index := Indexes (I);
            if Table (Index).Expire < Now then
               if Table (Index).Valid then
                  Table (Index).Valid := False;
               elsif Table (Index).Retry > 5 then
                  Table (Index).Unreachable := True;
                  Table (Index).Expire := Now + Arp_Unreachable_Timeout;
                  Table (Index).Retry := 0;
               else
                  Table (Index).Expire := Now + Arp_Retry_Timeout;
                  Target_Ip (Target_Ip'Last) := Uint8 (Index);
                  Request (Ifnet, Ifnet.Ip, Target_Ip, Ifnet.Mac);
               end if;
            end if;
         end loop;
      end Timeout;

      procedure Resolve (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                         Ip     : in Ip_Addr;
                         Mac    : out Ether_Addr;
                         Packet : in out Net.Buffers.Buffer_Type;
                         Result : out Arp_Status) is
         Index : constant Arp_Index := Arp_Index (Ip (Ip'Last));
         Now   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         if Table (Index).Valid and then Now < Table (Index).Expire then
            Mac := Table (Index).Ether;
            Result := ARP_FOUND;

         elsif Table (Index).Unreachable and then Now < Table (Index).Expire then
            Result := ARP_UNREACHABLE;

            --  Send the first ARP request for the target IP resolution.
         elsif not Table (Index).Pending then
            Table (Index).Pending := True;
            Table (Index).Retry   := 1;
            Table (Index).Expire  := Now + Arp_Retry_Timeout;
            Result := ARP_NEEDED;

         elsif Table (Index).Expire < Ada.Real_Time.Clock then
            if Table (Index).Retry > ARP_MAX_RETRY then
               Table (Index).Unreachable := True;
               Table (Index).Expire := Now + Arp_Unreachable_Timeout;
               Table (Index).Pending := False;
               Result := ARP_UNREACHABLE;
            else
               Table (Index).Retry := Table (Index).Retry + 1;
               Table (Index).Expire := Now + Arp_Retry_Timeout;
               Result := ARP_NEEDED;
            end if;
         else
            Result := ARP_PENDING;
         end if;
         if Result = ARP_PENDING or Result = ARP_NEEDED then
            if Queue_Size < QUEUE_LIMIT then
               Queue_Size := Queue_Size + 1;
               Net.Buffers.Insert (Table (Index).Queue, Packet);
               Table (Index).Queue_Size := Table (Index).Queue_Size + 1;
            else
               Result := ARP_QUEUE_FULL;
            end if;
         end if;
      end Resolve;

      procedure Update (Ip   : in Ip_Addr;
                        Mac  : in Ether_Addr;
                        List : out Net.Buffers.Buffer_List) is
         Index : constant Arp_Index := Arp_Index (Ip (Ip'Last));
      begin
         Table (Index).Ether := Mac;
         Table (Index).Valid := True;
         Table (Index).Unreachable := False;
         Table (Index).Pending := False;
         Table (Index).Expire := Ada.Real_Time.Clock + Arp_Entry_Timeout;

         --  If we have some packets waiting for the ARP resolution, return the packet list.
         if Table (Index).Queue_Size > 0 then
            Net.Buffers.Transfer (List, Table (Index).Queue);
            Queue_Size := Queue_Size - Table (Index).Queue_Size;
            Table (Index).Queue_Size := 0;
         end if;
      end Update;

   end Database;

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
