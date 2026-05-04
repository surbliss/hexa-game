module Game.Server (initServer) where

import Game.Logic (
  GameState,
  boardPlacements,
  initialGameState,
  legalMoves,
  movePiece,
 )
import Game.Protocol (
  ClientChan,
  ClientMessage (..),
  ClientRole (..),
  GameServer,
  PieceId,
  Placement,
  ServerMessage (..),
 )
import GenServer

data ServerState = ServerState
  { client1 :: ClientChan
  , client2 :: ClientChan
  , spectators :: ClientChan -- Just dup this, if more added
  , indicators :: Maybe (PieceId, [Placement]) -- What piece do the indicators belong to?
  , gameState :: GameState
  }

--- Exported
initServer :: IO GameServer
initServer = do
  c1 <- newChan
  c2 <- newChan
  c3 <- newChan
  let state =
        ServerState
          { client1 = c1
          , client2 = c2
          , spectators = c3
          , indicators = Nothing
          , gameState = initialGameState
          }
  spawn (handleServerMessage state)

handleServerMessage :: ServerState -> Chan ServerMessage -> IO ()
handleServerMessage state chan = do
  msg <- readChan chan
  newState <- handleServerMessage' state msg
  handleServerMessage newState chan

handleServerMessage' :: ServerState -> ServerMessage -> IO ServerState
handleServerMessage' state msg = case msg of
  SRegisterClient client rc -> do
    dc <- dupChan c -- NOTE: Remove when only one connection pr. player is enforced
    serverReply rc (dc, p, boardPlacements (gameState state))
    pure state
   where
    (c, p) = case client of
      Nothing -> (spectators state, Spectator)
      -- Just c' -> (getClientChan c' state, c') -- TEMP: For testing, spectator can move both
      Just c' -> (spectators state, Spectator)
  SClickPiece p i -> do
    writeChan
      (getClientChan p state)
      (CShowIndicators indPlaces)
    pure $ state{indicators = Just (i, indPlaces)}
   where
    indPlaces = legalMoves (gameState state) i
  SClickIndicator client i -> case indicators state of
    Nothing -> error "No indicators stored, rip"
    Just (pid, cs) -> do
      writeChan (getClientChan client state) (CMovePiece (pid, moveTo))
      pure $
        state
          { indicators = Nothing
          , gameState = movePiece pid moveTo (gameState state)
          }
     where
      moveTo = cs !! i

---------------------------------------------------
-- Helper-functions
---------------------------------------------------
getClientChan :: ClientRole -> ServerState -> ClientChan
getClientChan ActiveClient1 = client1
getClientChan ActiveClient2 = client2
getClientChan Spectator = spectators
