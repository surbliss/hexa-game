{-# LANGUAGE OverloadedStrings #-}

module Game.Protocol where

import Data.List (intercalate)
import Data.Maybe (isNothing, mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Game.Types (Coordinate (..), Height (..), Placement)
import GenServer
import Util

-- Module datatypes shared across the Socket and GameServer
data ClientMessage
  = CHello Piece -- Tmp, for testing
  | CInitPlayer ClientKind [Maybe Placement]
  | CMovePiece (Piece, Placement)
  | CShowIndicators [Placement] -- TODO: Add ID Indicators too!
  deriving (Eq, Show)

type GameServer = Server ServerMessage
type Indicator = Int

data ClientKind = ActiveClient1 | ActiveClient2 | Spectator deriving (Eq, Show)
type PlayerChan = Chan ClientMessage -- Message back to the client
data ServerMessage
  = SRegisterClient
      (Maybe ClientKind) -- Nothing if a new client that needs to be assigned
      (ReplyChan (PlayerChan, ClientKind, [Maybe Placement]))
  | SClickPiece ClientKind Piece
  | SClickIndicator ClientKind Piece
  deriving (Eq, Show)

type Piece = Int

--- Helper-class to convert to/from JS message-format
class Encodable a where
  encode :: a -> Text

instance Encodable ClientMessage where
  encode msg = case msg of
    CHello i -> "hello " <> T.show i
    -- No trailing spaces, if nothing placed yet!
    CInitPlayer clientKind xs | all isNothing xs -> T.intercalate " " ["init", encode clientKind]
    CInitPlayer player xs -> T.intercalate " " ["init", encode player, encode xs]
    CMovePiece piec -> "move " <> encode piec
    CShowIndicators xs -> "show-indicators " <> T.intercalate " " (map encode xs)

instance Encodable Placement where
  encode (Coord (x, y), Height z) = T.pack $ intercalate "," $ map show $ [x, y, z]

instance Encodable (Piece, Placement) where
  encode (i, p) = T.show i <> "," <> encode p

instance Encodable ClientKind where
  encode ActiveClient1 = "1"
  encode ActiveClient2 = "2"
  encode Spectator = "s"

instance Encodable [Maybe Placement] where
  encode xs = text
   where
    validPiece (i, Just coord) = Just $ encode (i, coord)
    validPiece (_, Nothing) = Nothing
    valids = mapMaybe validPiece $ zip [0 :: Piece ..] xs
    text = T.intercalate " " valids

-- Decoding
parseServerMessage :: ClientKind -> Text -> ServerMessage
parseServerMessage client text = case T.splitOn " " text of
  ["click", i] -> SClickPiece client (read (T.unpack i))
  ["click-indicator", i] -> SClickIndicator client (read (T.unpack i))
  other -> bug other
