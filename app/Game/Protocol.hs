{-# LANGUAGE OverloadedStrings #-}

module Game.Protocol where

import Data.List (intercalate)
import Data.Maybe (isNothing)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Vector (Vector)
import Data.Vector qualified as V
import GenServer
import Util

-- Module datatypes shared across the Socket and GameServer
data ClientMessage
  = CHello Piece -- Tmp, for testing
  | CInitPlayer Player (Vector (Maybe Coordinate))
  | CMovePiece (Piece, Coordinate)
  | CShowIndicators [Coordinate] -- TODO: Add ID Indicators too!
  deriving (Eq, Show)

type GameServer = Server ServerMessage
type Indicator = Int

type PlayerChan = Chan ClientMessage -- Message back to the client
data ServerMessage
  = SRegisterPlayer String (ReplyChan (PlayerChan, Player, Vector (Maybe Coordinate)))
  | SClickPiece Player Piece
  | SClickIndicator Player Piece
  deriving (Eq, Show)

type Piece = Int
data Player
  = Player1
  | Player2
  | Spectator
  deriving (Eq, Show)

type Coordinate = (Int, Int, Int)

--- Helper-class to convert to/from JS message-format
class Encodable a where
  encode :: a -> Text

instance Encodable ClientMessage where
  encode msg = case msg of
    CHello i -> "hello " <> T.show i
    -- No trailing spaces, if nothing placed yet!
    CInitPlayer player xs | all isNothing xs -> T.intercalate " " ["init", encode player]
    CInitPlayer player xs -> T.intercalate " " ["init", encode player, encode xs]
    CMovePiece piec -> "move " <> encode piec
    CShowIndicators xs -> "show-indicators " <> T.intercalate " " (map encode xs)

instance Encodable (Coordinate) where
  encode (x, y, z) = T.pack $ intercalate "," $ map show $ [x, y, z]

instance Encodable (Piece, Coordinate) where
  encode (i, coord) = T.show i <> "," <> encode coord

instance Encodable Player where
  encode Player1 = "1"
  encode Player2 = "2"
  encode Spectator = "s"

instance Encodable (Vector (Maybe Coordinate)) where
  encode xs = text
   where
    validPiece (i, Just coord) = Just $ encode (i, coord)
    validPiece (_, Nothing) = Nothing
    valids = V.mapMaybe validPiece $ V.indexed xs
    text = T.intercalate " " (V.toList valids)

-- Decoding
parseServerMessage :: Player -> Text -> ServerMessage
parseServerMessage player text = case T.splitOn " " text of
  ["click", i] -> SClickPiece player (read (T.unpack i))
  ["click-indicator", i] -> SClickIndicator player (read (T.unpack i))
  other -> bug other
