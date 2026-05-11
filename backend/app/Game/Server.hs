module Game.Server (initServer) where

import Game.Logic (
  GameState,
  boardRenderPositions,
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
  RenderPosition,
  ServerMessage (..),
  renderCoord,
 )
import GenServer

data ServerState = ServerState
  { client1 :: Maybe ClientChan
  , client2 :: Maybe ClientChan
  , spectators :: ClientChan -- Just dup this, if more added
  , indicators :: Maybe (PieceId, [RenderPosition]) -- What piece do the indicators belong to?
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
   where

  -- dc <- dupChan c -- NOTE: Remove when only one connection pr. player is enforced
  -- serverReply rc (dc, p, boardRenderPositions (gameState state))
  -- pure state

  -- (c, p) = case client of
  --   Nothing -> (spectators state, Spectator)
  --   -- Just c' -> (getClientChan c' state, c') -- TEMP: For testing, spectator can move both
  --   Just _ -> (spectators state, Spectator)
  SClickPiece client i -> do
    case getClientChan client state of
      Just c -> writeChan c (CShowIndicators indRenderPositions)
      Nothing -> pure ()
    pure $ state{indicators = Just (i, indRenderPositions)}
   where
    indRenderPositions = legalMoves (gameState state) i
  SClickIndicator client i -> case (client, indicators state) of
    (_, Nothing) -> error "No indicators stored, rip"
    (Spectator, _) -> pure state{indicators = Nothing} -- Don't react to spectator pressing and indicator
    (_, Just (pid, cs)) ->
      case getClientChan client state of
        Just c -> do
          writeChan c (CMovePiece (pid, moveTo))
          pure $
            state
              { indicators = Nothing
              , gameState = movePiece pid (renderCoord moveTo) (gameState state)
              }
        Nothing -> pure state
     where
      moveTo = cs !! i

---------------------------------------------------
-- Helper-functions
---------------------------------------------------
getClientChan :: ClientRole -> ServerState -> Maybe ClientChan
getClientChan ActiveClient1 = client1
getClientChan ActiveClient2 = client2
getClientChan Spectator = Just . spectators
