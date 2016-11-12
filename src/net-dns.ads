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
with Net.Headers;
with Ada.Real_Time;
with Net.Interfaces;
with Net.Buffers;
with Net.Sockets.Udp;
package Net.DNS is

   DNS_NAME_MAX_LENGTH : constant Positive := 255;

   type Status_Type is (NOQUERY, NOERROR, FORMERR, SERVFAIL, NXDOMAIN, NOTIMP,
                        REFUSED, YXDOMAIN, XRRSET, NOTAUTH, NOTZONE, OTHERERROR, PENDING);

   type Query is new Net.Sockets.Udp.Socket with private;

   function Get_Status (Request : in Query) return Status_Type;

   --  Get the name defined for the DNS query.
   function Get_Name (Request : in Query) return String;

   --  Get the IP address that was resolved by the DNS query.
   function Get_Ip (Request : in Query) return Net.Ip_Addr;

   procedure Resolve (Request : access Query;
                      Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                      Name    : in String;
                      Timeout : in Natural := 10);

   overriding
   procedure Receive (Request  : in out Query;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

private

   type Query is new Net.Sockets.Udp.Socket with record
      Name     : String (1 .. DNS_NAME_MAX_LENGTH);
      Name_Len : Natural := 0;
      Status   : Status_Type := NOQUERY;
      Deadline : Ada.Real_Time.Time;
      Xid      : Net.Uint16;
      Ip       : Net.Ip_Addr := (others => 0);
      Ttl      : Net.Uint32;
   end record;

end Net.DNS;
