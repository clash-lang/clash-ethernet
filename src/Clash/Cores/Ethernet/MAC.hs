module Clash.Cores.Ethernet.MAC ( macCircuits, txMACCircuit, rxMACCircuit ) where

import Clash.Cores.Ethernet.Stream ( SingleByteStream, TaggedStream )
import Clash.Prelude
import Protocols
import Protocols.Axi4.Stream

-- Components
import Clash.Cores.Ethernet.CDC ( circuitCDC )
import Clash.Cores.Ethernet.MAC.ConstructHeader
import Clash.Cores.Ethernet.MAC.DeconstructHeader
import Clash.Cores.Ethernet.MAC.FCS
import Clash.Cores.Ethernet.MAC.IFG
import Clash.Cores.Ethernet.MAC.Padding
import Clash.Cores.Ethernet.MAC.Preamble
import Clash.Cores.Ethernet.MAC.PreambleRemover
import Clash.Cores.Ethernet.Utils ( downconverter, upconverter )

macCircuits :: forall (edom        :: Domain)
                      (mdom        :: Domain)
   . (KnownDomain edom, KnownDomain mdom)
  => Clock edom
  -> Reset edom
  -> Enable edom
  -> Clock mdom
  -> Reset mdom
  -> Enable mdom
  -> ( Circuit (SingleByteStream edom) (TaggedStream mdom)
     , Circuit (TaggedStream mdom) (SingleByteStream edom)
     )
macCircuits ethClk ethRst ethEn clk rst en = (rxMACCircuit ethClk ethRst ethEn clk rst en, txMACCircuit ethClk ethRst ethEn clk rst en)

txMACCircuit :: forall (edom        :: Domain)
                       (mdom        :: Domain)
   . (KnownDomain edom, KnownDomain mdom)
  => Clock edom
  -> Reset edom
  -> Enable edom
  -> Clock mdom
  -> Reset mdom
  -> Enable mdom
  -> Circuit (TaggedStream mdom) (SingleByteStream edom)
txMACCircuit ethClk ethRst ethEn clk rst en = withEth $ ifgEnforcer
                                                     <| preambleInserter
                                                     <| fcsAppender
                                                     <| constructHeader
                                                     <| payloadPadder
                                                     <| downconverter
                                                     <| circuitCDC clk ethClk rst ethRst en ethEn
  where
    withEth = withClockResetEnable ethClk ethRst ethEn

rxMACCircuit :: forall (edom        :: Domain)
                       (mdom        :: Domain)
   . (KnownDomain edom, KnownDomain mdom)
  => Clock edom
  -> Reset edom
  -> Enable edom
  -> Clock mdom
  -> Reset mdom
  -> Enable mdom
  -> Circuit (SingleByteStream edom) (TaggedStream mdom)
rxMACCircuit ethClk ethRst ethEn clk rst en = withEth $ circuitCDC ethClk clk ethRst rst ethEn en
                                                     <| upconverter
                                                     <| deconstructHeader
                                                     -- <| crcChecker
                                                     <| undefined
                                                     <| preambleRemover
  where
    withEth = withClockResetEnable ethClk ethRst ethEn
