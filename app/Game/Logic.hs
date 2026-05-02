module Game.Logic (
  GameState,
  Placement,
  initialGameState,
  legalMoves,
  movePiece,
  boardPlacements,
) where

import Control.Exception (assert)
import Data.Set (Set)
import Data.Set qualified as S
import Data.Vector (Vector, (!), (//))
import Data.Vector qualified as V
import Game.Protocol (Placement (..))

---------------------------------------------------
-- Data-types
---------------------------------------------------
--- Exported datatypes

-- | All the info about gamestate, that changes throughout. Constructors _not_ exported
data GameState = GameState
  { locations :: Vector Location
  , coordinates :: Vector Coordinate
  , heights :: Vector Height
  , currentPlayer :: Player
  , turn :: Int
  , boardRim :: Set Coordinate -- All pieces touching a board-pice, but not occupied by any
  }

--- Internal datatypes
data Direction = U | D | UR | DR | UL | DL deriving (Eq, Show, Ord)

-- Combined piece-state
newtype Coordinate = Coord (Int, Int) deriving (Eq, Show, Ord)
newtype Height = Height Int deriving (Eq, Show, Ord)
data Location = Stock | Board deriving (Eq, Show, Ord)

-- For indexing into piece-array
type PieceId = Int

-- Which player is allowed to move
data Player = Player1 | Player2 deriving (Eq, Show, Ord)

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
-- Note: Export stuff as _lists_ to avoid Vector-dependency when importing
-- Also, use 'Placement' from Protocol module, so Server does not have to look at internals of Logic when sending game-info
legalMoves :: GameState -> PieceId -> [Placement]
legalMoves state i
  | turn state == 0 && currentPlayer state == Player1 =
      [Placement (0, 0, 0)]
  | locations state ! i == Stock =
      hiveRim state
  | otherwise = case pieceKinds ! i of
      Purple -> placementH (Height 2) <$> S.toList adjs
      Orange
        | turn state == 0 -> []
        | otherwise -> undefined
      _ -> placement0 <$> S.toList adjs
 where
  c = coordinates state ! i
  adjs = adjCoords c

-- placedCoordinates = V.map (\(_, y) -> y) $ V.filter (\(x, _) -> x == Board) $ V.zip (locations state) (coordinates state)

-- Maybe Placement: Nothing if in stock, Just p if placed on board
boardPlacements :: GameState -> [Maybe Placement]
boardPlacements state = map onBoard (V.toList xs)
 where
  xs = V.zip3 (locations state) (coordinates state) (heights state)
  onBoard (Stock, _, _) = Nothing
  onBoard (Board, c, h) = Just (placementH h c)

movePiece :: PieceId -> Placement -> GameState -> GameState
movePiece i p@(Placement (x, y, z)) state =
  assert
    (p `elem` legalMoves state i)
    state
      { coordinates = coordinates state // [(i, c)]
      , heights = heights state // [(i, h)]
      , locations = locations state // [(i, Board)]
      , currentPlayer = nextPlayer
      , turn = nextTurn
      }
 where
  c = Coord (x, y)
  h = Height z
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
    , boardRim = S.singleton (Coord (0, 0)) -- Convention: Empty board has the center as the 'rim' (only possible first placement)
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

adjCoords :: Coordinate -> Set Coordinate
adjCoords c = S.fromList $ map (\d -> step d c) [U, D, UR, DR, UL, DL]

placedCoords :: GameState -> Set Coordinate
placedCoords state = S.fromList $ V.toList $ V.map (\(_, y) -> y) $ V.filter (\(x, _) -> x == Board) $ V.zip (locations state) (coordinates state)

hiveRim :: GameState -> [Placement]
hiveRim state = placeAdjs
 where
  placed = placedCoords state
  allAdjs = S.unions $ S.map adjCoords placed
  freeAdjs = allAdjs S.\\ placed
  placeAdjs = S.toAscList $ S.map placement0 freeAdjs

placement0 :: Coordinate -> Placement
placement0 (Coord (x, y)) = Placement (x, y, 0)

placementH :: Height -> Coordinate -> Placement
placementH (Height z) (Coord (x, y)) = Placement (x, y, z)
