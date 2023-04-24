{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleContexts #-}


module Clash.Lattice.ECP5.Colorlight.CDC ( circuitCDC ) where

import Clash.Prelude
import Clash.Explicit.Synchronizer ( asyncFIFOSynchronizer )
import Protocols.Axi4.Stream

type BufEl = (Vec 4 Byte, Index 4)
type Byte = BitVector 8

data RState = Accumulating BufEl | Empty
  deriving (Show, ShowX, Eq, Generic, NFDataX)
data WState = Idle | Writing BufEl
  deriving (Show, ShowX, Eq, Generic, NFDataX)

nextByte :: BufEl -> (Byte, Maybe BufEl)
nextByte (vec, 0) = (head vec, Nothing)
nextByte (vec, n) = (head vec, Just $ (rotateLeftS vec d1, n-1))


-- CDC as circuit
circuitCDC :: forall (wdom        :: Domain)
                     (rdom        :: Domain)
                     (conf        :: Axi4StreamConfig)
                     (userType    :: Type)
   . (KnownDomain wdom, KnownDomain rdom, KnownAxi4StreamConfig conf, NFDataX userType)
  => Clock wdom
  -> Clock rdom
  -> Reset wdom
  -> Reset rdom
  -> Enable wdom
  -> Enable rdom
  -> (Signal wdom (Maybe (Axi4StreamM2S conf userType)),
      Signal rdom (Axi4StreamS2M))
  -> ( Signal rdom (Maybe (Axi4StreamM2S conf userType))
     , Signal wdom (Axi4StreamS2M)
     )
circuitCDC wClk rClk wRst rRst wEn rEn ipt = (otp_m2s', otp_s2m')
    where
        (m2s, s2m) = ipt
        (m2s', empty, full) = asyncFIFOSynchronizer d3 wClk rClk wRst rRst wEn rEn readReq m2s
        otp_m2s' = mux empty (pure Nothing) (Just <$> m2s')
        otp_s2m' = bundle $ (\x -> Axi4StreamS2M { _tready = not x }) <$> full
        readReq :: Signal rdom Bool
        readReq = _tready <$> s2m
