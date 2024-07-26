-----------------------------------------------------------------------
--  net-stm32_svd -- Ethernet driver for STM32F74x (SVD base)
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

with System;

pragma Warnings (Off, "is an internal GNAT unit");
with Interfaces.STM32;
pragma Warnings (On, "is an internal GNAT unit");

package Net.STM32_SVD is
   pragma Preelaborate;

   Ethernet_DMA_Base : System.Address renames
     Interfaces.STM32.Ethernet_DMA_Base;

   Ethernet_MAC_Base : System.Address renames
     Interfaces.STM32.Ethernet_MAC_Base;

   Ethernet_MMC_Base : System.Address renames
     Interfaces.STM32.Ethernet_MMC_Base;

   Ethernet_PTP_Base : System.Address renames
     Interfaces.STM32.Ethernet_PTP_Base;

end Net.STM32_SVD;
