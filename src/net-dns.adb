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
with Interfaces; use Interfaces;
with Net.Headers;
with Net.Utils;
package body Net.DNS is

   --  The IN class for the DNS response (RFC 1035, 3.2.4. CLASS values).
   --  Other classes are not meaningly to us.
   IN_CLASS : constant Net.Uint16 := 16#0001#;

   procedure Skip_Query (Packet : in out Net.Buffers.Buffer_Type);

   protected body Request is
      procedure Set_Result (Addr : in Net.Ip_Addr;
                            Time : in Net.Uint32) is
      begin
         Ip  := Addr;
         Ttl := Time;
         Status := NOERROR;
      end Set_Result;

      procedure Set_Status (State : in Status_Type) is
      begin
         Status := State;
      end Set_Status;

      function Get_IP return Net.Ip_Addr is
      begin
         return Ip;
      end Get_IP;

      function Get_Status return Status_Type is
      begin
         return Status;
      end Get_Status;

      function Get_TTL return Net.Uint32 is
      begin
         return Ttl;
      end Get_TTL;

   end Request;

   function Get_Status (Request : in Query) return Status_Type is
   begin
      return Request.Result.Get_Status;
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
      return Request.Result.Get_IP;
   end Get_Ip;

   --  ------------------------------
   --  Get the TTL associated with the response.
   --  ------------------------------
   function Get_Ttl (Request : in Query) return Net.Uint32 is
   begin
      return Request.Result.Get_TTL;
   end Get_Ttl;

   --  ------------------------------
   --  Start a DNS resolution for the given hostname.
   --  ------------------------------
   procedure Resolve (Request : access Query;
                      Ifnet   : access Net.Interfaces.Ifnet_Type'Class;
                      Name    : in String;
                      Status  : out Error_Code;
                      Timeout : in Duration := 10.0) is
      use type Ada.Real_Time.Time;

      Xid  : constant Uint32 := Net.Utils.Random;
      Addr : Net.Sockets.Sockaddr_In;
      To   : Net.Sockets.Sockaddr_In;
      Buf  : Net.Buffers.Buffer_Type;
      C    : Character;
      Cnt  : Net.Uint8;
   begin
      Request.Name_Len := Name'Length;
      Request.Name (1 .. Name'Length) := Name;
      Request.Result.Set_Status (PENDING);
      Addr.Port := Net.Uint16 (Shift_Right (Xid, 16));
      Request.Xid := Net.Uint16 (Xid and 16#0ffff#);
      Request.Bind (Ifnet, Addr);
      Request.Deadline := Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (Timeout);
      Net.Buffers.Allocate (Buf);
      Buf.Set_Type (Net.Buffers.UDP_PACKET);
      Buf.Put_Uint16 (Request.Xid);
      Buf.Put_Uint16 (16#0100#);
      Buf.Put_Uint16 (1);
      Buf.Put_Uint16 (0);
      Buf.Put_Uint16 (0);
      Buf.Put_Uint16 (0);
      for I in 1 .. Request.Name_Len loop
         C := Request.Name (I);
         if C = '.' or I = 1 then
            Cnt := (if I = 1 then 1 else 0);
            for J in I + 1 .. Request.Name_Len loop
               C := Request.Name (J);
               exit when C = '.';
               Cnt := Cnt + 1;
            end loop;
            Buf.Put_Uint8 (Cnt);
            if I = 1 then
               Buf.Put_Uint8 (Character'Pos (Request.Name (1)));
            end if;
         else
            Buf.Put_Uint8 (Character'Pos (C));
         end if;
      end loop;
      Buf.Put_Uint8 (0);
      Buf.Put_Uint16 (Net.Uint16 (A_RR));
      Buf.Put_Uint16 (IN_CLASS);
      To.Port := Net.Headers.To_Network (53);
      To.Addr := Ifnet.Dns;
      Request.Send (To, Buf, Status);
   end Resolve;

   --  ------------------------------
   --  Save the answer received from the DNS server.  This operation is called for each answer
   --  found in the DNS response packet.  The Index is incremented at each answer.  For example
   --  a DNS server can return a CNAME_RR answer followed by an A_RR: the operation is called
   --  two times.
   --
   --  This operation can be overriden to implement specific actions when an answer is received.
   --  ------------------------------
   procedure Answer (Request  : in out Query;
                     Status   : in Status_Type;
                     Response : in Response_Type;
                     Index    : in Natural) is
      pragma Unreferenced (Index);
   begin
      if Status /= NOERROR then
         Request.Result.Set_Status (Status);
      elsif Response.Of_Type = A_RR then
         Request.Result.Set_Result (Response.Ip, Response.Ttl);
      end if;
   end Answer;

   procedure Skip_Query (Packet : in out Net.Buffers.Buffer_Type) is
      Cnt : Net.Uint8;
   begin
      loop
         Cnt := Packet.Get_Uint8;
         exit when Cnt = 0;
         Packet.Skip (Net.Uint16 (Cnt));
      end loop;
      --  Skip QTYPE and QCLASS in query.
      Packet.Skip (2);
      Packet.Skip (2);
   end Skip_Query;

   overriding
   procedure Receive (Request  : in out Query;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      pragma Unreferenced (From);

      Val     : Net.Uint16;
      Answers : Net.Uint16;
      Ttl     : Net.Uint32;
      Len     : Net.Uint16;
      Cls     : Net.Uint16;
      Status  : Status_Type;
   begin
      Val := Packet.Get_Uint16;
      if Val /= Request.Xid then
         return;
      end if;
      Val := Packet.Get_Uint16;
      if (Val and 16#ff00#) /= 16#8100# then
         return;
      end if;
      if (Val and 16#0F#) /= 0 then
         case Val and 16#0F# is
            when 1 =>
               Status := FORMERR;

            when 2 =>
               Status := SERVFAIL;

            when 3 =>
               Status := NXDOMAIN;

            when 4 =>
               Status := NOTIMP;

            when  5 =>
               Status := REFUSED;

            when others =>
               Status := OTHERERROR;

         end case;
         Query'Class (Request).Answer (Status, Response_Type '(Kind => V_NONE, Len => 0,
                                                               Class => 0,
                                                               Of_Type => 0, Ttl => 0), 0);
         return;
      end if;
      Val := Packet.Get_Uint16;
      Answers := Packet.Get_Uint16;
      if Val /= 1 or else Answers = 0 then
         Query'Class (Request).Answer (SERVFAIL, Response_Type '(Kind => V_NONE, Len => 0,
                                                                 Class => 0,
                                                                 Of_Type => 0, Ttl => 0), 0);
         return;
      end if;
      Packet.Skip (4);
      Skip_Query (Packet);
      for I in 1 .. Answers loop
         Packet.Skip (2);
         Val := Packet.Get_Uint16;
         Cls := Packet.Get_Uint16;
         Ttl := Packet.Get_Uint32;
         Len := Packet.Get_Uint16;
         if Cls = IN_CLASS and Len < Net.Uint16 (DNS_VALUE_MAX_LENGTH) then
            case RR_Type (Val) is
               when A_RR =>
                  declare
                     Response : constant Response_Type
                       := Response_Type '(Kind    => V_IPV4, Len => Natural (Len),
                                          Of_Type => RR_Type (Val), Ttl => Ttl,
                                          Class   => Cls, Ip => Packet.Get_Ip);
                  begin
                     Query'Class (Request).Answer (NOERROR, Response, Natural (I));
                  end;

               when CNAME_RR | TXT_RR | MX_RR | NS_RR | PTR_RR =>
                  declare
                     Response : Response_Type
                       := Response_Type '(Kind    => V_TEXT, Len => Natural (Len),
                                          Of_Type => RR_Type (Val), Ttl => Ttl,
                                          Class   => Cls, others => <>);
                  begin
                     for J in Response.Text'Range loop
                        Response.Text (J) := Character'Val (Packet.Get_Uint8);
                     end loop;
                     Query'Class (Request).Answer (NOERROR, Response, Natural (I));
                  end;

               when others =>
                  --  Ignore this answer: we don't know its type.
                  Packet.Skip (Len);

            end case;
         else
            --  Ignore this anwser.
            Packet.Skip (Len);
         end if;
      end loop;
   end Receive;

end Net.DNS;
