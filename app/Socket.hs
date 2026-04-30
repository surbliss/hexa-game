{-# LANGUAGE OverloadedStrings #-}

module Socket where

import Network.WebSockets (
  Connection,
  PendingConnection,
  acceptRequest,
  receiveData,
  sendTextData,
 )

import Control.Monad (forever)
import Data.List (intercalate)
import Data.Text (Text, splitOn, unpack)
import Data.Text qualified as T
import Data.Vector (Vector, (//))
import Data.Vector qualified as V
import Debug.Trace (trace, traceShowId)
import GenServer

type GameServer = Server ServerMessage
type PlayerChan = Chan ClientMessage -- Message back to the client
type Piece = Int
type Coordinate = (Int, Int, Int)

echo :: String -> IO ()
echo s = putStrLn $ "INFO: " <> s

bug :: (Show a) => a -> b
bug x = error $ "BUG: " <> (show x)

data Player
  = Player1
  | Player2
  | Spectator

data ServerMessage
  = SInitPlayer Text (ReplyChan (PlayerChan, Player, Vector (Maybe Coordinate)))
  | SClickPiece Player Piece

data GameMessage
  = GReqPiecePositions (ReplyChan ([(Piece, Coordinate)]))

data ClientMessage
  = CHello Piece -- Tmp, for testing
  | CInitPlayer Player (Vector (Maybe Coordinate))
  | CMovePiece (Piece, Coordinate)

data GameState = GameState
  { player1 :: PlayerChan
  , player2 :: PlayerChan
  , spectators :: PlayerChan -- Just dup this, if more added
  , pieces :: Vector (Maybe (Int, Int, Int))
  }
initGameState :: IO GameState
initGameState = do
  c1 <- newChan
  c2 <- newChan
  c3 <- newChan
  pure $
    GameState
      { player1 = c1
      , player2 = c2
      , spectators = c3
      , pieces = V.replicate 11 Nothing // [(2, Just (0, 1, 0))]
      }

socketApp :: GameServer -> PendingConnection -> IO ()
socketApp gameServer pendingConnection = do
  con <- acceptRequest pendingConnection
  -- Get player info (must be 'connect ...')
  text <- receiveData con
  (outChan, player, pieces) <- case splitOn " " text of
    ["connect", token] -> do
      requestReply gameServer $ SInitPlayer token
    _ -> bug text
  _ <- forkIO $ forever $ do
    msg <- readChan outChan
    sendTextData con (traceShowId $ encodeMessage msg)
  sendTextData con (encodeMessage $ CInitPlayer player pieces)
  confirmConnection con
  -- Initial thread, for confirming the connection
  forever $ do
    (msg :: Text) <- receiveData con
    serverSend gameServer (parseMessage player msg)

confirmConnection :: Connection -> IO ()
confirmConnection con = do
  (text :: Text) <- receiveData con
  case traceShowId (T.splitOn " " text) of
    ["setup-done", i] -> echo ("Setup finished for player " <> T.unpack i) >> pure ()
    other -> trace ("Wrong first message: " <> show other) confirmConnection con

parseMessage :: Player -> Text -> ServerMessage
parseMessage player text = case splitOn " " text of
  ["click", i] -> SClickPiece player (read (unpack i))
  other -> bug other

encodeMessage :: ClientMessage -> Text
encodeMessage msg = case msg of
  CHello i -> "hello " <> T.show i
  CInitPlayer player xs -> T.intercalate " " ["init", playerToId player, packPieces xs]
  CMovePiece piec -> "move " <> showPiece piec

playerToId :: Player -> Text
playerToId Player1 = "1"
playerToId Player2 = "2"
playerToId Spectator = "s"

packPieces :: Vector (Maybe Coordinate) -> Text
packPieces xs = text
 where
  validPiece (i, Just coord) = Just $ showPiece (i, coord)
  validPiece (_, Nothing) = Nothing
  valids = V.mapMaybe validPiece $ V.indexed xs
  text = T.intercalate " " (V.toList valids)
showPiece :: (Piece, Coordinate) -> Text
showPiece (i, (x, y, z)) = T.pack $ intercalate "," $ map show $ [i, x, y, z]

handleServerMessage :: GameState -> Chan ServerMessage -> IO ()
handleServerMessage state chan = do
  msg <- readChan chan
  newState <- handleServerMessage' state msg
  handleServerMessage newState chan

handleServerMessage' :: GameState -> ServerMessage -> IO GameState
handleServerMessage' state msg = do
  case msg of
    SInitPlayer text rc -> do
      let
      serverReply rc (c, p, pieces state)
      pure state
     where
      (c, p) = case text of
        "new" -> (player1 state, Player1) -- TODO: Add check if player 1 already added
        "1" -> (player1 state, Player1)
        "2" -> (player2 state, Player2)
        "s" -> (spectators state, Spectator)
        other -> error $ "Invalid player token: " <> unpack other
    SClickPiece p i -> do
      let
        newPos = (-2, 2, 0)
        newState = state{pieces = pieces state // [(i, Just newPos)]}
      writeChan (getPlayerChan p state) (CMovePiece (i, newPos))
      pure newState

getPlayerChan :: Player -> GameState -> PlayerChan
getPlayerChan Player1 = player1
getPlayerChan Player2 = player2
getPlayerChan Spectator = spectators
