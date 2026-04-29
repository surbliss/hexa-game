{-# LANGUAGE OverloadedStrings #-}

module Socket where

import Network.WebSockets (
  PendingConnection,
  acceptRequest,
  receiveData,
  sendTextData,
 )

import Control.Monad (forever)
import Data.Text (Text, splitOn, unpack)
import Data.Text qualified as T
import Data.Vector (Vector, (//))
import Data.Vector qualified as V
import GenServer

type GameServer = Server ServerMessage
type PlayerChan = Chan ClientMessage -- Message back to the client
type Piece = Int
type Coordinate = (Int, Int, Int)

data Player
  = Player1
  | Player2
  | Spectator

data ServerMessage
  = SNewPlayer Text (ReplyChan (Player, PlayerChan))
  | SClickPiece Player Piece

data GameMessage
  = GReqPiecePositions (ReplyChan ([(Piece, Coordinate)]))

data ClientMessage
  = CPlayerToken Player
  | CHello Piece -- Tmp, for testing

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
      , pieces = V.replicate 11 Nothing // [(2, Just (1, 1, 0))]
      }

socketApp :: GameServer -> PendingConnection -> IO ()
socketApp gameServer pendingConnection = do
  con <- acceptRequest pendingConnection
  -- Get player info (must be 'connect ...')
  text <- receiveData con
  (player, outChan) <- case splitOn " " text of
    ["connect", token] -> do
      requestReply gameServer $ SNewPlayer token
    other -> error $ "Invalid first message: " <> concat (map unpack other)
  sendTextData con (encodeMessage $ CPlayerToken player)
  _ <- forkIO $ forever $ do
    msg <- readChan outChan
    let textMsg = encodeMessage msg
    print textMsg
    sendTextData con (encodeMessage msg)
  forever $ do
    (msg :: Text) <- receiveData con
    serverSend gameServer (parseMessage player msg)

parseMessage :: Player -> Text -> ServerMessage
parseMessage player text = case splitOn " " text of
  ["click", i] -> SClickPiece player (read (unpack i))
  other -> error $ "Invalid message send by client: " <> concat (map unpack other)

encodeMessage :: ClientMessage -> Text
encodeMessage msg = case msg of
  CPlayerToken Player1 -> "player-id 1"
  CPlayerToken Player2 -> "player-id 2"
  CPlayerToken Spectator -> "player-id s"
  CHello i -> "hello " <> T.show i

handleServerMessage :: GameState -> Chan ServerMessage -> IO ()
handleServerMessage state chan = do
  msg <- readChan chan
  newState <- handleServerMessage' state msg
  handleServerMessage newState chan

handleServerMessage' :: GameState -> ServerMessage -> IO GameState
handleServerMessage' state msg = do
  case msg of
    SNewPlayer text rc -> do
      serverReply rc $ case text of
        "new" -> (Player1, player1 state) -- TODO: Add check if player 1 already added
        "1" -> (Player1, player1 state)
        "2" -> (Player2, player2 state)
        "s" -> (Spectator, spectators state)
        other -> error $ "Invalid player token: " <> unpack other
      pure state
    SClickPiece p i -> do
      writeChan (getPlayerChan p state) (CHello i)
      pure state

-- SClickPiece p i -> writeChan undefined (getPlayerChan p state)
printTextError :: [Text] -> a
printTextError xs = error $ "Invalid msg: " <> concat (map unpack xs)

getPlayerChan :: Player -> GameState -> PlayerChan
getPlayerChan Player1 = player1
getPlayerChan Player2 = player2
getPlayerChan Spectator = spectators
