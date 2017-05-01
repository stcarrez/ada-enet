-----------------------------------------------------------------------
--  time_manager -- NTP Client instance
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

with Net.NTP;
with Net.DNS;
package Time_Manager is

   type Client_Type is new Net.DNS.Query with record
      Server : aliased Net.NTP.Client;
      Port   : Net.Uint16 := Net.NTP.NTP_PORT;
   end record;

   --  Save the answer received from the DNS server.  This operation is called for each answer
   --  found in the DNS response packet.  The Index is incremented at each answer.  For example
   --  a DNS server can return a CNAME_RR answer followed by an A_RR: the operation is called
   --  two times.
   --
   --  This operation can be overriden to implement specific actions when an answer is received.
   overriding
   procedure Answer (Request  : in out Client_Type;
                     Status   : in Net.DNS.Status_Type;
                     Response : in Net.DNS.Response_Type;
                     Index    : in Natural);

   --  NTP client based on the NTP server provided by DHCP option.
   Client     : aliased Net.NTP.Client;

   --  NTP client to the "ntp.ubuntu.com" server.
   Ubuntu_Ntp : aliased Client_Type;

   --  NTP client to the "pool.ntp.org" server (at least one of them).
   Pool_Ntp   : aliased Client_Type;

   --  NTP client to the "ntp.bouyguesbox.fr" server.
   Bbox_Ntp   : aliased Client_Type;

end Time_Manager;
