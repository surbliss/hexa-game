module Game.Server (initServer) where

import Control.Concurrent (dupChan)
import Data.Vector.Unboxed qualified as V
import Game.Logic (initialGameState, legalMoves, movePiece)
import Game.Protocol
import Game.Types
import GenServer

data ServerState = ServerState
  { client1 :: PlayerChan
  , client2 :: PlayerChan
  , spectators :: PlayerChan -- Just dup this, if more added
  , indicators :: Maybe (Piece, [Placement]) -- What piece do the indicators belong to?
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
    serverReply rc (dc, p, placements state)
    pure state
   where
    (c, p) = case client of
      Nothing -> (client1 state, ActiveClient1) -- TODO: Add check if player 1 already added
      Just c' -> (getClientChan c' state, c')
  SClickPiece p i -> do
    writeChan
      (getClientChan p state)
      (CShowIndicators indPlaces)
    pure $ state{indicators = Just (i, indPlaces)}
   where
    indPlaces = V.toList $ legalMoves (gameState state) i
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
placements :: ServerState -> [Maybe Placement]
placements state = map onBoard (V.toList xs)
 where
  gstate = gameState state
  xs = V.zip3 (locations gstate) (coordinates gstate) (heights gstate)
  onBoard (Stock, _, _) = Nothing
  onBoard (Board, c, h) = Just (c, h)

getClientChan :: ClientKind -> ServerState -> PlayerChan
getClientChan ActiveClient1 = client1
getClientChan ActiveClient2 = client2
getClientChan Spectator = spectators
