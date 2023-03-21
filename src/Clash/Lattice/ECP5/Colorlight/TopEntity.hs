module Clash.Lattice.ECP5.Colorlight.TopEntity (topEntity) where

import Data.Maybe ( isNothing )

import Clash.Annotations.TH
import Clash.Explicit.Prelude
import Clash.Lattice.ECP5.Colorlight.CRG
import Clash.Lattice.ECP5.Prims
import Clash.Prelude ( exposeClockResetEnable )

import Clash.Cores.Ethernet.MDIO ( mdioComponent )
import Clash.Lattice.ECP5.Colorlight.Bridge ( uartToMdioBridge )

data RGMIIChannel domain = RGMIIChannel
  {
    rgmii_clk  :: "clk" ::: Clock domain,
    rgmii_ctl  :: "ctl" ::: Signal domain Bit,
    rgmii_data :: "data" ::: Signal domain (BitVector 4)
  }

data SDRAMOut domain = SDRAMOut
  {
    sdram_clock :: "clk" :::Clock domain,
    sdram_a :: "a" ::: Signal domain (BitVector 11),
    sdram_we_n :: "we_n" ::: Signal domain Bit,
    sdram_ras_n :: "ras_n" :::Signal domain Bit,
    sdram_cas_n :: "cas_n" ::: Signal domain Bit,
    sdram_ba :: "ba" ::: Signal domain (BitVector 2),
    sdram_dq :: "dq" ::: BiSignalOut 'Floating domain 32
  }

data MDIOOut domain = MDIOOut
  {
    mdio_out :: "mdio" ::: BiSignalOut 'Floating domain 1,
    mdio_mdc :: "mdc" ::: Signal domain Bit
  }

data HubOut domain = HubOut
  {
    hub_clk :: "clk" ::: Signal domain Bit,
    hub_line_select :: "line_select" ::: Signal domain (BitVector 5),
    hub_latch :: "latch" ::: Signal domain Bit,
    hub_output_enable :: "output_enable" ::: Signal domain Bit,
    hub_data :: "data" ::: Signal domain (BitVector 48)
  }

topEntity
  :: "clk25" ::: Clock Dom25
  -> "uart_rx" ::: Signal Dom50 Bit
  -> "sdram_dq" ::: BiSignalIn 'Floating Dom50 32
  -> "eth_mdio" ::: BiSignalIn 'Floating Dom50 1
  -> "eth0_rx" ::: RGMIIChannel DomEth0
  -> "eth1_rx" ::: RGMIIChannel DomEth1
  -> ( "uart_tx" ::: Signal Dom50 Bit
     , "sdram" ::: SDRAMOut Dom50
     , "eth" ::: MDIOOut Dom50
     , "eth0_tx" ::: RGMIIChannel DomEth0
     , "eth1_tx" ::: RGMIIChannel DomEth1
     , "hub" ::: HubOut Dom50
     )
topEntity clk25 uartRxBit _dq_in mdio_in eth0_rx eth1_rx =
  let
    (clk50, rst50) = crg clk25
    en50 = enableGen

    -- MDIO component
    mdio, mdioReg :: Signal Dom50 Bit
    (mdio_output, mdio) = bb mdio_in
                         (register clk50 rst50 en50 1 $ boolToBit . isNothing <$> mdioWrite)
                         (ofs1p3bx clk50 rst50 en50 $ fromJustX <$> mdioWrite)

    mdioReg = ifs1p3bx clk50 rst50 en50 mdio
    (mdioWrite, mdioResponse, mdc) = (exposeClockResetEnable mdioComponent clk50 rst50 en50) mdioReg mdioRequest

    -- UART-MDIO bridge
    (uartTxBit, mdioRequest) = (ofs1p3bx clk50 rst50 en50 $ txBit, req)
      where
        (txBit, req) = (exposeClockResetEnable uartToMdioBridge clk50 rst50 en50) (SNat @9600) rxBit mdioResponse
        rxBit = ifs1p3bx clk50 rst50 en50 uartRxBit

    -- TODO: What to do with this one?
    dq_out = undefined

    in
      ( uartTxBit
      , SDRAMOut
          { sdram_clock = clk50
          , sdram_a = pure 0
          , sdram_we_n = pure 1
          , sdram_ras_n = pure 1
          , sdram_cas_n = pure 1
          , sdram_ba = pure 0
          , sdram_dq = dq_out
          }
      , MDIOOut
          { mdio_out = mdio_output
          , mdio_mdc = mdc
          }
      , RGMIIChannel  -- eth0
          { rgmii_clk = rgmii_clk eth0_rx
          , rgmii_ctl = rgmii_ctl eth0_rx
          , rgmii_data = rgmii_data eth0_rx
          }
      , RGMIIChannel  --eth1
          { rgmii_clk = rgmii_clk eth1_rx
          , rgmii_ctl = rgmii_ctl eth1_rx
          , rgmii_data = rgmii_data eth1_rx
          }
      , HubOut
          { hub_clk = pure 0
          , hub_line_select = pure 0
          , hub_latch = pure 0
          , hub_output_enable = pure 0
          , hub_data = pure 0
          }
      )

makeTopEntity 'topEntity
