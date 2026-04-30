module Game.Server (initGameServer) where

import Control.Concurrent (dupChan)
import Data.Vector (Vector, (!), (//))
import Data.Vector qualified as V
import Game.Protocol
import GenServer

-- Could consider name 'ServerState' instead, reserving 'GameState' name for non-server-related state
data GameState = GameState
  { player1 :: PlayerChan
  , player2 :: PlayerChan
  , spectators :: PlayerChan -- Just dup this, if more added
  , pieces :: Vector (Maybe (Int, Int, Int))
  , indicators :: Maybe (Piece, [Coordinate]) -- What piece do the indicators belong to?
  }
  deriving (Eq)

--- Exported
initGameServer :: IO GameServer
initGameServer = do
  gameState <- initGameState
  spawn (handleServerMessage gameState)

--- Private
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
      , pieces = V.replicate 11 Nothing // [(2, Just (0, 1, 0)), (1, Just (1, -1, 0))]
      , indicators = Nothing
      }

handleServerMessage :: GameState -> Chan ServerMessage -> IO ()
handleServerMessage state chan = do
  msg <- readChan chan
  newState <- handleServerMessage' state msg
  handleServerMessage newState chan

handleServerMessage' :: GameState -> ServerMessage -> IO GameState
handleServerMessage' state msg = case msg of
  SRegisterPlayer text rc -> do
    dc <- dupChan c -- NOTE: Remove when only one connection pr. player is enforced
    serverReply rc (dc, p, pieces state)
    pure state
   where
    (c, p) = case text of
      "new" -> (player1 state, Player1) -- TODO: Add check if player 1 already added
      "1" -> (player1 state, Player1)
      "2" -> (player2 state, Player2)
      "s" -> (spectators state, Spectator)
      other -> error $ "Invalid player token: " <> other
  SClickPiece p i -> do
    writeChan (getPlayerChan p state) (CShowIndicators surroundingPos)
    pure $ state{indicators = Just (i, surroundingPos)}
   where
    ps = pieces state
    (x, y) = case ps ! i of
      Just (x', y', _) -> (x', y')
      Nothing -> error "clicked non-existing piece, gg"
    surroundingPos =
      [ (x, y + 1, 0)
      , (x, y - 1, 0)
      , (x + 1, y, 0)
      , (x - 1, y, 0)
      , (x + 1, y - 1, 0)
      , (x - 1, y + 1, 0)
      ]
  SClickIndicator p i -> case indicators state of
    Nothing -> error "No indicators stored, rip"
    Just (pid, cs) -> do
      writeChan (getPlayerChan p state) (CMovePiece (pid, cs !! i))
      pure
        state
          { pieces = pieces state // [(pid, Just (cs !! i))]
          , indicators = Nothing
          }

getPlayerChan :: Player -> GameState -> PlayerChan
getPlayerChan Player1 = player1
getPlayerChan Player2 = player2
getPlayerChan Spectator = spectators
