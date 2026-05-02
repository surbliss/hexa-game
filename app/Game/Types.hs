{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Game.Types where

import Data.Vector.Unboxed (Vector)
import Data.Vector.Unboxed.Deriving (derivingUnbox)
import Data.Word (Word8)

-- | All the info about gamestate, that changes throughout
data GameState = GameState
  { locations :: Vector Location
  , coordinates :: Vector Coordinate
  , heights :: Vector Height
  , currentPlayer :: Player
  , turn :: Int
  }

-- Combined piece-state
newtype Coordinate = Coord (Int, Int) deriving (Eq, Show)
newtype Height = Height Int deriving (Eq, Show)
data Location = Stock | Board deriving (Eq, Show)
type Placement = (Coordinate, Height)

-- For indexing into piece-array
type PieceId = Int

-- Which player is allowed to move
data Player = Player1 | Player2 deriving (Eq, Show)

-- Using their color for now
data PieceKind
  = Orange -- queen
  | Green -- hopper
  | Blue -- soldier
  | Red -- Spider
  | Purple -- Beetle
  deriving (Eq, Show)

-- Allowing using these types as unboxed vectors
derivingUnbox
  "Coordinate"
  [t|Coordinate -> (Int, Int)|]
  [|\(Coord t) -> t|]
  [|Coord|]
derivingUnbox
  "Height"
  [t|Height -> (Int)|]
  [|\(Height t) -> t|]
  [|Height|]
derivingUnbox
  "Location"
  [t|Location -> Bool|]
  [|
    \p -> case p of
      Stock -> False
      Board -> True
    |]
  [|
    \b -> case b of
      False -> Stock
      True -> Board
    |]
derivingUnbox
  "PieceKind"
  [t|PieceKind -> Word8|]
  [|
    \p -> case p of
      Orange -> 0
      Purple -> 1
      Red -> 2
      Green -> 3
      Blue -> 4
    |]
  [|
    \w -> case w of
      0 -> Orange
      1 -> Purple
      2 -> Red
      3 -> Green
      _ -> Purple
    |]
