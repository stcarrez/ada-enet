-----------------------------------------------------------------------
--  net-dns -- DNS Network utilities
--  Copyright (C) 2016, 2017 Stephane Carrez
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
with Net.Interfaces;
with Net.Buffers;
with Net.Sockets.Udp;

--  == DNS Client ==
--  The DNS client is used to make a DNS resolution and resolve a hostname to get an IP address
--  (RFC 1035).  The client implementation is based on the UDP client sockets and it uses a
--  random UDP port to receive the DNS response.
--
--  === Initialization ===
--  The DNS client is represented by the <tt>Query</tt> tagged type.  An instance must be declared
--  for each hostname that must be resolved.
--
--    Client : Net.DNS.Query;
--
--  === Hostname resolution ===
--  The hostname resolution is started by calling the <tt>Resolve</tt> operation on the query
--  object.  That operation needs an access to the network interface to be able to send the
--  DNS query packet.  It returns a status code that indicates whether the packet was sent or not.
--
--    Client.Resolve (Ifnet'Access, "www.google.com", Status);
--
--  The DNS resolution is asynchronous.  The <tt>Resolve</tt> operation does not wait for the
--  response.  The <tt>Get_Status</tt> operation can be used to look at the progress of the DNS
--  query.  The value <tt>PENDING</tt> indicates that a request was sent but no response was
--  received yet.  The value <tt>NOERROR</tt> indicates that the DNS resolution was successful.
--
--  Once the <tt>Get_Status</tt> operation returns the <tt>NOERROR</tt> value, the IPv4 address
--  can be obtained by using the <tt>Get_Ip</tt> function.
--
--    IP : Net.Ip_Addr := Client.Get_Ip;
package Net.DNS is

   --  Maximum length allowed for a hostname resolution.
   DNS_NAME_MAX_LENGTH  : constant Positive := 255;

   --  Maximum length accepted by a response anwser.  The official limit is 64K but this
   --  implementation limits the length of DNS records to 512 bytes which is more than acceptable.
   DNS_VALUE_MAX_LENGTH : constant Positive := 512;

   --  The DNS query status.
   type Status_Type is (NOQUERY, NOERROR, FORMERR, SERVFAIL, NXDOMAIN, NOTIMP,
                        REFUSED, YXDOMAIN, XRRSET, NOTAUTH, NOTZONE, OTHERERROR, PENDING);

   --  The DNS record type is a 16-bit number.
   type RR_Type is new Net.Uint16;

   --  Common standard DNS record type values from RFC 1035, RFC 3586)
   --  (See http://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml)
   A_RR     : constant RR_Type := 1;
   NS_RR    : constant RR_Type := 2;
   CNAME_RR : constant RR_Type := 5;
   PTR_RR   : constant RR_Type := 12;
   MX_RR    : constant RR_Type := 15;
   TXT_RR   : constant RR_Type := 16;
   AAAA_RR  : constant RR_Type := 28;

   --  The possible value types in the response.
   type Value_Type is (V_NONE, V_TEXT, V_IPV4, V_IPV6);

   --  The Response_Type record describes a response anwser that was received from the
   --  DNS server.  The DNS server can send several response answers in the same packet.
   --  The answer data is extracted according to the RR type and made available as String,
   --  IPv4 and in the future IPv6.
   type Response_Type (Kind    : Value_Type;
                       Of_Type : RR_Type;
                       Len     : Natural) is
      record
         Class    : Net.Uint16;
         Ttl      : Net.Uint32;
         case Kind is
         when V_TEXT => --  CNAME_RR | TXT_RR | MX_RR | NS_RR | PTR_RR
            Text : String (1 .. Len);

         when V_IPV4 => --  A_RR
            Ip   : Net.Ip_Addr;

         when others =>
            null;

         end case;
      end record;

   type Query is new Net.Sockets.Udp.Socket with private;

   function Get_Status (Request : in Query) return Status_Type;

   --  Get the name defined for the DNS query.
   function Get_Name (Request : in Query) return String;

   --  Get the IP address that was resolved by the DNS query.
   function Get_Ip (Request : in Query) return Net.Ip_Addr;

   --  Get the TTL associated with the response.
   function Get_Ttl (Request : in Query) return Net.Uint32;

   --  Start a DNS resolution for the given hostname.
   procedure Resolve (Request : access Query;
                      Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                      Name    : in String;
                      Status  : out Error_Code;
                      Timeout : in Duration := 10.0) with
     Pre  => Name'Length < DNS_NAME_MAX_LENGTH,
     Post => Request.Get_Status /= NOQUERY;

   --  Save the answer received from the DNS server.  This operation is called for each answer
   --  found in the DNS response packet.  The Index is incremented at each answer.  For example
   --  a DNS server can return a CNAME_RR answer followed by an A_RR: the operation is called
   --  two times.
   --
   --  This operation can be overriden to implement specific actions when an answer is received.
   procedure Answer (Request  : in out Query;
                     Status   : in Status_Type;
                     Response : in Response_Type;
                     Index    : in Natural);

   overriding
   procedure Receive (Request  : in out Query;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

private

   protected type Request is
      procedure Set_Result (Addr : in Net.Ip_Addr;
                            Time : in Net.Uint32);
      procedure Set_Status (State : in Status_Type);
      function Get_IP return Net.Ip_Addr;
      function Get_Status return Status_Type;
      function Get_TTL return Net.Uint32;
   private
      Status   : Status_Type := NOQUERY;
      Ip       : Net.Ip_Addr := (others => 0);
      Ttl      : Net.Uint32;
   end Request;

   type Query is new Net.Sockets.Udp.Socket with record
      Name     : String (1 .. DNS_NAME_MAX_LENGTH);
      Name_Len : Natural := 0;
      Deadline : Ada.Real_Time.Time;
      Xid      : Net.Uint16;
      Result   : Request;
   end record;

end Net.DNS;
