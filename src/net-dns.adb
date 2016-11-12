-----------------------------------------------------------------------
--  net-dns -- DNS Network utilities
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
with Interfaces; use Interfaces;
with Net.Buffers;
package body Net.DNS is

   function Get_Status (Request : in Query) return Status_Type is
   begin
      return Request.Status;
   end Get_Status;

   --  ------------------------------
   --  Get the name defined for the DNS query.
   --  ------------------------------
   function Get_Name (Request : in Query) return String is
   begin
      return Request.Name (1 .. Request.Name_Len);
   end Get_Name;

   --  ------------------------------
   --  Get the IP address that was resolved by the DNS query.
   --  ------------------------------
   function Get_Ip (Request : in Query) return Net.Ip_Addr is
   begin
      return Request.Ip;
   end Get_Ip;

   procedure Resolve (Request : access Query;
                      Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                      Name    : in String;
                      Timeout : in Natural := 10) is
      Xid  : Uint32 := Ifnet.Random;
      Addr : Net.Sockets.Sockaddr_In;
      To   : Net.Sockets.Sockaddr_In;
      Buf  : Net.Buffers.Buffer_Type;
   begin
      Request.Name_Len := Name'Length;
      Request.Name (1 .. Name'Length) := Name;
      Request.Status := PENDING;
      Addr.Port := Net.Uint16 (Shift_Right (Xid, 16));
      Request.Xid := Net.Uint16 (Xid and 16#0ffff#);
      Request.Bind (Ifnet, Addr);
      Buf.Set_Type (Net.Buffers.UDP_PACKET);
      Buf.Put_Uint16 (Request.Xid);
      Buf.Put_Uint16 (16#0100#);
      Buf.Put_Uint16 (1);
      Buf.Put_Uint16 (0);
      Buf.Put_Uint16 (0);
      Buf.Put_Uint8 (3);
      Buf.Put_String (Request.Name (1 .. Request.Name_Len), With_Null => True);
      Buf.Put_Uint16 (1);
      Buf.Put_Uint16 (1);
      To.Port := 53;
      To.Addr := Ifnet.Dns;
      Request.Send (To, Buf);
   end Resolve;

   overriding
   procedure Receive (Request  : in out Query;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
   begin
      null;
   end Receive;

end Net.DNS;
