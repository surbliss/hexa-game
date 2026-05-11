module Game.Server (initServer) where

import Game.Logic (
  GameState,
  TurnState (..),
  boardRenderPositions,
  initialGameState,
  legalMoves,
  movePiece,
  turnState,
 )
import Game.Protocol (
  ClientChan,
  ClientMessage (..),
  ClientRole (..),
  GameServer,
  PieceId,
  RenderPosition,
  ServerMessage (..),
  renderCoord,
 )
import GenServer
import Util

data ServerState = ServerState
  { client1 :: Maybe ClientChan
  , client2 :: Maybe ClientChan
  , spectators :: ClientChan -- Just dup this, if more added
  , indicators :: Maybe (PieceId, [RenderPosition]) -- Currently active indicators, from the active player
  , activeClient :: ClientRole
  , gameState :: GameState
  }

--- Exported
initServer :: IO GameServer
initServer = do
  spectatorChan <- newChan
  let state =
        ServerState
          { client1 = Nothing
          , client2 = Nothing
          , spectators = spectatorChan
          , indicators = Nothing
          , gameState = initialGameState
          , activeClient = ActiveClient1
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
    sc <- dupChan (spectators state)
    (chan, p, new_state) <- case client of
      Just (Spectator) -> pure (sc, Spectator, state)
      Just (ActiveClient1) -> case client1 state of
        Just c -> pure (c, ActiveClient1, state)
        Nothing -> error "Non-existing client1 connected"
      Just (ActiveClient2) -> case client2 state of
        Just c -> pure (c, ActiveClient2, state)
        Nothing -> error "Non-existing client2 connected"
      Nothing -> case (client1 state, client2 state) of
        (Nothing, _) -> do
          c <- newChan
          pure (c, ActiveClient1, state{client1 = Just c})
        (Just _, Nothing) -> do
          c <- newChan
          pure (c, ActiveClient2, state{client2 = Just c})
        (Just _, Just _) -> pure (sc, Spectator, state)

    serverReply rc (chan, p, boardRenderPositions (gameState new_state))
    pure new_state
  SClickPiece client i ->
    if client /= activeClient state
      then pure state
      else do
        case getClientChan client state of
          Just c -> writeChan c (CShowIndicators indRenderPositions)
          Nothing -> pure ()
        pure $ state{indicators = Just (i, indRenderPositions)}
   where
    indRenderPositions = legalMoves (gameState state) i
  --- Here is where the active player might switch!
  SClickIndicator client i -> case (activeClient state, indicators state) of
    (ac, _) | client /= ac -> pure state
    (_, Nothing) -> error "No indicators stored, rip"
    (_, Just (pid, cs)) -> do
      sendAll state (CMovePiece (pid, moveTo))
      pure $ putGameState newGameState state
     where
      moveTo = cs !! i
      newGameState = movePiece pid (renderCoord moveTo) (gameState state)
  SUnregisterClient role -> case role of
    ActiveClient1 -> pure state{client1 = Nothing}
    ActiveClient2 -> pure state{client2 = Nothing}
    Spectator -> do
      warn "Spectator disconnected, should not happen"
      pure state

---------------------------------------------------
-- Helper-functions
---------------------------------------------------
getClientChan :: ClientRole -> ServerState -> Maybe ClientChan
getClientChan ActiveClient1 = client1
getClientChan ActiveClient2 = client2
getClientChan Spectator = Just . spectators

putGameState :: GameState -> ServerState -> ServerState
putGameState gstate sstate =
  sstate
    { gameState = gstate
    , activeClient = nextActiveClient
    , indicators = Nothing
    }
 where
  nextActiveClient = case turnState gstate of
    Player1Turn -> ActiveClient1
    Player2Turn -> ActiveClient2
    -- No more actions then
    Player1Won -> Spectator
    Player2Won -> Spectator
    Draw -> Spectator

sendAll :: ServerState -> ClientMessage -> IO ()
sendAll state msg = do
  send (client1 state)
  send (client2 state)
  writeChan (spectators state) msg
 where
  send c = mapM_ (`writeChan` msg) c
