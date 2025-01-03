-----------------------------------------------------------------------
--  net-interfaces-stm32 -- Ethernet driver for STM32F74x
--  Copyright (C) 2016-2024 Stephane Carrez
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
with Ethernet.MDIO;

with Net.Buffers;
with Net.Interfaces;

private with Net.STM32_SVD.Ethernet;
private with Interfaces;
with System.STM32;

--  === STM32 MAC and MDIO Driver ===
--
--  This package provides both a network driver for the STM32 and an MDIO
--  driver. In most cases it is sufficient to call Configure before using
--  the driver:
--
--  MAC : aliased Net.STM32_Interfaces.STM32_Ifnet;
--
--  MAC.Configure (Net.STM32_Interfaces.STM32F407_Pins, RMII => True);
--
--  But, if necessary, you can start MDIO first, configure the PHY with the
--  Read_Register/Write_Register and then start the Eth driver.
--
--  MAC : aliased Net.STM32_Interfaces.STM32_Ifnet;
--
--  MAC.MDIO.Configure (Net.STM32_Interfaces.STM32F407_Pins);
--  --  Check link status and/or configure PHY to route CLK_REF signal:
--  MAC.MDIO.Write_Register (PHY =>1, Register =>2, Value => 3, Success => Ok);
--  --  Now enable MAC driver
--  MAC.Configure (Net.STM32_Interfaces.STM32F407_Pins, RMII => True);
--

package Net.STM32_Interfaces is

   subtype Pin_Port is Character range 'A' .. 'I';
   subtype Pin_Index is Natural range 0 .. 15;

   --  Pin designation on stm32 consist of port and pin index, e.g.
   --  PA10 is ('A', 10) or (Port => 'A', Index => 10).
   type Pin is record
      Port  : Pin_Port;
      Index : Pin_Index;
   end record;

   --  An array of STM32 pins
   type Pin_Array is array (Positive range <>) of Pin;

   --  Ethernet pins for STM32F429, STM32F746 and STM32F769 Discovery boards:
   --
   STM32F42X_Pins : constant Pin_Array :=
     (('A', 1),    --  PA1  - RMII_REF_CLK
      ('A', 2),    --  PA2  - RMII_MDIO
      ('A', 7),    --  PA7  - RMII_CRS_DV
      ('C', 1),    --  PC1  - RMII_MDC
      ('C', 4),    --  PC4  - RMII_RXD0
      ('C', 5),    --  PC5  - RMII_RXD1
      ('G', 2),    --  PG2  - RMII_RXER
      ('G', 11),   --  PG11 - RMII_TX_EN,
      ('G', 13),   --  PG13 - RMII_TXD0,
      ('G', 14));  --  PG14 - RMII_TXD1

   --  Ethernet pins for a simple STM32F407 boards:
   --
   STM32F407_Pins : constant Pin_Array :=
     (('A', 1),   --  PA1  - RMII_REF_CLK
      ('A', 2),   --  PA2  - RMII_MDIO
      ('A', 7),   --  PA7  - RMII_CRS_DV
      ('B', 11),  --  PB11 - RMII_TX_EN,
      ('B', 12),  --  PB12 - RMII_TXD0,
      ('B', 13),  --  PB13 - RMII_TXD1,
      ('C', 1),   --  PC1  - RMII_MDC
      ('C', 4),   --  PC4  - RMII_RXD0
      ('C', 5));  --  PC5  - RMII_RXD1

   --  MDIO (AKA Station management interface, SMI)
   type STM32_MDIO_Interface is new Ethernet.MDIO.MDIO_Interface with private;

   --  Configure pins and enable only MDIO/SMI part of MAC
   procedure Configure
     (Self : in out STM32_MDIO_Interface'Class;
      Pins : Pin_Array;
      HCLK : System.STM32.Frequency := System.STM32.System_Clocks.HCLK);

   --  Match MDIO/SMI device clock to specified frequency
   procedure Set_Clock_Frequency
     (Self : in out STM32_MDIO_Interface'Class;
      HCLK : System.STM32.Frequency := System.STM32.System_Clocks.HCLK);

   --  Read MDIO register on PHY
   overriding
   procedure Read_Register
     (Self     : in out STM32_MDIO_Interface;
      PHY      : Ethernet.MDIO.PHY_Index;
      Register : Ethernet.MDIO.Register_Index;
      Value    : out Standard.Interfaces.Unsigned_16;
      Success  : out Boolean);

   --  Write MDIO register on PHY
   overriding
   procedure Write_Register
     (Self     : in out STM32_MDIO_Interface;
      PHY      : Ethernet.MDIO.PHY_Index;
      Register : Ethernet.MDIO.Register_Index;
      Value    : Standard.Interfaces.Unsigned_16;
      Success  : out Boolean);

   --  The STM32F Ethernet driver.
   type STM32_Ifnet is limited new Net.Interfaces.Ifnet_Type with record
      MDIO : aliased STM32_MDIO_Interface;
      --  MDIO (AKA Station management interface, SMI) interface
   end record;

   --  Reset and configure STM32 peripherals.
   --
   --  If Wait=True, the procedure will reset the STM32 peripherals
   --  and complete the configuration before returning. Ensure that the
   --  corresponding PHY is configured beforehand to provide the CLK_REF
   --  signal to the STM32 chip if needed.
   --
   --  If Wait=False, the procedure initiates the reset and returns
   --  immediately. In this case, you must wait for the reset to complete
   --  (using Is_Reset_Complete) and then call Enable to finalize the
   --  configuration.
   procedure Configure
     (Ifnet : in out STM32_Ifnet'Class;
      Pins  : Pin_Array;
      Wait  : Boolean := True;
      RMII  : Boolean := True;
      HCLK  : System.STM32.Frequency := System.STM32.System_Clocks.HCLK);

   --  Check if reset is done and CLK_REF is detected
   function Is_Reset_Complete (Ifnet : STM32_Ifnet'Class) return Boolean;

   --  Enable the STM32 Ethernet device after it has been reset or disabled.
   procedure Enable (Ifnet : in out STM32_Ifnet'Class)
     with Pre => Ifnet.Is_Reset_Complete;

   --  Disable the STM32 Ethernet device. To re-enable it, call Reset followed
   --  by Enable.
   procedure Disable (Ifnet : in out STM32_Ifnet'Class);

   --  Perform a software reset of the STM32 MAC subsystem, clearing
   --  all internal registers and logic.
   procedure Reset (Ifnet : in out STM32_Ifnet'Class);

   --  Send a packet to the interface.
   overriding
   procedure Send (Ifnet : in out STM32_Ifnet;
                   Buf   : in out Net.Buffers.Buffer_Type);

   --  Receive a packet from the interface.
   overriding
   procedure Receive (Ifnet : in out STM32_Ifnet;
                      Buf   : in out Net.Buffers.Buffer_Type);

   --  Returns true if the interface driver is ready to receive or send packets
   function Is_Ready (Ifnet : STM32_Ifnet) return Boolean;

private

   type STM32_MDIO_Interface is new Ethernet.MDIO.MDIO_Interface with record
      CR : Net.STM32_SVD.Ethernet.MACMIIAR_CR_Field := 0;
   end record;

   --  Initialize the network interface.
   procedure Initialize (Ifnet : in out STM32_Ifnet);

end Net.STM32_Interfaces;
