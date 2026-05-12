{-# LANGUAGE OverloadedStrings #-}

-- | Datatypes shared across the Game- Socket and Server
module Game.Protocol where

import Data.List (intercalate)
import Data.Maybe (isNothing, mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Debug.Trace (traceShowId)
import GenServer
import Util

--- Messages
type BoardPositions = [Maybe RenderPosition] -- NOTE: _Has_ to be precisely length 22
data ClientMessage
  = CHello PieceId -- Tmp, for testing
  | CInitPlayer ClientRole TurnState BoardPositions -- NOTE: _Has_ to be length 22
  | CMovePiece TurnState (PieceId, RenderPosition)
  | CShowIndicators [RenderPosition] -- TODO: Add ID Indicators too!
  deriving (Eq, Show)

data ServerMessage
  = SRegisterClient
      (Maybe ClientRole) -- Nothing if a new client that needs to be assigned
      (ReplyChan (ClientChan, ClientRole, TurnState, BoardPositions))
  | SUnregisterClient ClientRole -- Player 1 or 2 dissconnected
  | SClickPiece ClientRole PieceId
  | SClickIndicator ClientRole PieceId
  deriving (Eq, Show)

-- Whose turn it is, or, if relevant, if the game is Over
data TurnState
  = Player1Turn
  | Player2Turn
  | Player1Won
  | Player2Won
  | Draw
  deriving (Eq, Show)

--- Server
type GameServer = Server ServerMessage

-- Corresponds into an index into a fixed-length array (list or vector)
type IndicatorId = Int
type PieceId = Int

-- Role of the connected client
data ClientRole = ActiveClient1 | ActiveClient2 | Spectator deriving (Eq, Show)

-- The channel a specific client recieves messages from
type ClientChan = Chan ClientMessage -- Message back to the client

{- | Datatype to communicate placement of Pieces to the client.
 The tuple is (x, y, z), i.e. (x, y) being hexagonal coordinates, and z being height (if placed on top of another piece)
We use 'Maybe RenderPosition' for pieces, that might be in the stock, and hence not placed yet
-}
newtype RenderPosition = RenderPosition (Int, Int, Int) deriving (Eq, Show, Ord)

-- Convert to tuple
renderCoord :: RenderPosition -> (Int, Int)
renderCoord (RenderPosition (x, y, _)) = (x, y)

--- Helper-class to convert to/from JS message-format
class Encodable a where
  encode :: a -> Text

instance Encodable ClientMessage where
  encode msg = case msg of
    CHello i -> "hello " <> T.show i
    -- No trailing spaces, if nothing placed yet!
    CInitPlayer clientKind turn xs | all isNothing xs -> traceShowId $ T.intercalate " " ["init", encode clientKind, encode turn]
    CInitPlayer clientKind turn xs -> T.intercalate " " ["init", encode clientKind, encode turn, encode xs]
    CMovePiece turn piec -> T.intercalate " " ["move", encode turn, encode piec]
    CShowIndicators xs
      | null xs -> "show-indicators"
      | otherwise -> "show-indicators " <> T.intercalate " " (map encode xs)

instance Encodable RenderPosition where
  encode (RenderPosition (x, y, z)) = T.pack $ intercalate "," $ map show $ [x, y, z]

instance Encodable (PieceId, RenderPosition) where
  encode (i, p) = T.show i <> "," <> encode p

instance Encodable ClientRole where
  encode ActiveClient1 = "1"
  encode ActiveClient2 = "2"
  encode Spectator = "s"

instance Encodable TurnState where
  encode Player1Turn = "t1"
  encode Player2Turn = "t2"
  encode Player1Won = "n"
  encode Player2Won = "n"
  encode Draw = "n"

instance Encodable BoardPositions where
  encode xs = text
   where
    validPiece (i, Just coord) = Just $ encode (i, coord)
    validPiece (_, Nothing) = Nothing
    valids = mapMaybe validPiece $ zip [0 :: PieceId ..] (traceShowId xs)
    text = T.intercalate " " valids

-- Decoding
parseServerMessage :: ClientRole -> Text -> ServerMessage
parseServerMessage client text = case T.splitOn " " text of
  ["click", i] -> SClickPiece client (read (T.unpack i))
  ["click-indicator", i] -> SClickIndicator client (read (T.unpack i))
  other -> bug other
