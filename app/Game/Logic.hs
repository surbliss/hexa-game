module Game.Logic (
  GameState (..),
  Coordinate (..),
  Location (..),
  Height (..),
  Placement,
  initialGameState,
  legalMoves,
  movePiece,
) where

import Control.Exception (assert)
import Data.Vector (Vector, (!), (//))
import Data.Vector qualified as V
import Debug.Trace (traceShowId)

---------------------------------------------------
-- Data-types
---------------------------------------------------

-- | All the info about gamestate, that changes throughout
data GameState = GameState
  { locations :: Vector Location
  , coordinates :: Vector Coordinate
  , heights :: Vector Height
  , currentPlayer :: Player
  , turn :: Int
  }

data Direction = U | D | UR | DR | UL | DL deriving (Eq, Show)

-- Combined piece-state
newtype Coordinate = Coord (Int, Int) deriving (Eq, Show)
newtype Height = Height Int deriving (Eq, Show)
data Location = Stock | Board deriving (Eq, Show)
type Placement = (Coordinate, Height)

-- For indexing into piece-array
type PieceId = Int

-- Which player is allowed to move
data Player = Player1 | Player2 deriving (Eq, Show)

-- Using their color for now
data PieceKind
  = Orange -- queen
  | Green -- hopper
  | Blue -- soldier
  | Red -- Spider
  | Purple -- Beetle
  deriving (Eq, Show)

---------------------------------------------------
-- Exported functionality
---------------------------------------------------
legalMoves :: GameState -> PieceId -> Vector Placement
legalMoves state i
  | turn state == 0 && currentPlayer state == Player1
      || locations state ! i == Stock =
      V.singleton (Coord (0, 0), Height (0))
  | otherwise = case pieceKinds ! i of
      _ -> traceShowId $ V.map (\x -> (x, Height 0)) adjs
 where
  c = coordinates state ! i
  adjs = adjCoordinates c

movePiece :: PieceId -> Placement -> GameState -> GameState
movePiece i (c, h) state =
  assert
    ((c, h) `V.elem` legalMoves state i)
    state
      { coordinates = coordinates state // [(i, c)]
      , heights = heights state // [(i, h)]
      , locations = locations state // [(i, Board)]
      , currentPlayer = nextPlayer
      , turn = nextTurn
      }
 where
  (nextPlayer, nextTurn) = case (currentPlayer state) of
    Player1 -> (Player2, turn state)
    Player2 -> (Player1, turn state + 1)

---------------------------------------------------
-- Static game info
---------------------------------------------------
--- Public
initialGameState :: GameState
initialGameState =
  GameState
    { locations = V.replicate 22 Stock
    , coordinates = V.replicate 22 (Coord (0, 0))
    , heights = V.replicate 22 (Height 0)
    , currentPlayer = Player1
    , turn = 0
    }

--- Private
pieceKinds :: Vector PieceKind
pieceKinds =
  V.fromListN 22 $ ps <> ps
 where
  ps =
    [ Blue
    , Blue
    , Blue
    , Green
    , Green
    , Green
    , Red
    , Red
    , Purple
    , Purple
    , Orange
    ]

_pieceOwner :: PieceId -> Player
_pieceOwner n
  | n < 0 = error $ "Piece ID " <> show n <> " below bounds (21)"
  | n < 11 = Player1
  | n < 22 = Player2
  | otherwise = error $ "Piece ID " <> show n <> " above bounds (21)"

---------------------------------------------------
-- Modifying game-state
---------------------------------------------------

step :: Direction -> Coordinate -> Coordinate
step dir (Coord (x, y)) = Coord $ case dir of
  U -> (x, y + 1)
  D -> (x, y - 1)
  UR -> (x + 1, y)
  DR -> (x + 1, y - 1)
  UL -> (x - 1, y + 1)
  DL -> (x - 1, y)

adjCoordinates :: Coordinate -> Vector Coordinate
adjCoordinates c = V.fromList $ map (\d -> step d c) [U, D, UR, DR, UL, DL]
