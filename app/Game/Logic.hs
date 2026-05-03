module Game.Logic (
  GameState,
  Placement,
  initialGameState,
  legalMoves,
  movePiece,
  boardPlacements,
) where

import Control.Exception (assert)
import Control.Monad (guard)
import Data.Map.Strict qualified as M
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
legalMoves state i | currentPlayer state /= pieceOwner i = []
legalMoves state i = case (turn state, currentPlayer state, locations state ! i, pieceKinds ! i) of
  (1, _, _, Orange) -> [] -- No queen in first move, for either player
  (1, Player1, _, _) -> [Placement (0, 0, 0)] -- Always start in center
  (1, Player2, _, _) -> placement0 <$> (S.toList $ boardRim state)
  (4, _, Stock, k) | k /= Orange && orangeIsInStock state -> []
  (_, _, Stock, _) -> S.toList $ stockMoves state
  (_, _, Board, _)
    | orangeIsInStock state -> []
    | any (\(c, h) -> c == cNow && h > hNow) chs -> []
    | not $ isConnected $ S.delete cNow $ (placedCoords state) -> []
  --- Board moves
  (_, _, Board, Purple) -> purpleMoves state cNow
  (_, _, Board, Orange) -> orangeMoves state cNow
  (_, _, Board, Green) -> greenMoves state cNow
  (_, _, Board, Blue) -> placement0 <$> (S.toList $ boardRim state)
  (_, _, Board, Red) -> redMoves state cNow
 where
  cNow = coordinates state ! i
  hNow = heights state ! i
  chs = onBoard $ V.zip (locations state) $ V.zip (coordinates state) (heights state)

orangeIsInStock :: GameState -> Bool
orangeIsInStock state = case (currentPlayer state) of
  Player1 -> locations state ! 10 == Stock
  Player2 -> locations state ! 21 == Stock

-- placedCoordinates = V.map (\(_, y) -> y) $ V.filter (\(x, _) -> x == Board) $ V.zip (locations state) (coordinates state)

-- Maybe Placement: Nothing if in stock, Just p if placed on board
boardPlacements :: GameState -> [Maybe Placement]
boardPlacements state = map place (V.toList xs)
 where
  xs = V.zip3 (locations state) (coordinates state) (heights state)
  place (Stock, _, _) = Nothing
  place (Board, c, h) = Just (placementH h c)

movePiece :: PieceId -> Placement -> GameState -> GameState
movePiece i p@(Placement (x, y, z)) state =
  assert
    (p `elem` legalMoves state i)
    state
      { coordinates = coordinates state // [(i, newC)]
      , heights = heights state // [(i, h)]
      , locations = locations state // [(i, Board)]
      , currentPlayer = nextPlayer
      , turn = nextTurn
      }
 where
  newC = Coord (x, y)
  h = Height z
  (nextPlayer, nextTurn) = case (currentPlayer state) of
    Player1 -> (Player2, turn state)
    Player2 -> (Player1, turn state + 1)

boardRim :: GameState -> Set Coordinate
boardRim state = adjs S.\\ placed
 where
  placed = placedCoords state
  adjs = S.unions $ S.map adjCoords placed

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
    , turn = 1
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

pieceOwner :: PieceId -> Player
pieceOwner n
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

allDirections :: [Direction]
allDirections = [U, D, UR, DR, UL, DL]

adjCoords :: Coordinate -> Set Coordinate
adjCoords c = S.fromList $ map (\d -> step d c) allDirections

placedCoords :: GameState -> Set Coordinate
placedCoords state = S.fromList $ V.toList $ V.map (\(_, y) -> y) $ V.filter (\(x, _) -> x == Board) $ V.zip (locations state) (coordinates state)

placement0 :: Coordinate -> Placement
placement0 (Coord (x, y)) = Placement (x, y, 0)

placementH :: Height -> Coordinate -> Placement
placementH (Height z) (Coord (x, y)) = Placement (x, y, z)

--- Piece-movement while on the board, per piece-type
stockMoves :: GameState -> Set Placement
stockMoves state = S.map placement0 $ boardRim state S.\\ otherPlayerAdjs
 where
  otherPlayerPieces :: Vector (Location, Coordinate)
  otherPlayerPieces = case currentPlayer state of
    Player1 -> V.slice 11 11 (V.zip (locations state) (coordinates state))
    Player2 -> V.slice 0 11 (V.zip (locations state) (coordinates state))
  otherPlayerCoords :: Set Coordinate
  otherPlayerCoords = toSet $ onBoard otherPlayerPieces
  otherPlayerAdjs = S.unions $ S.map adjCoords otherPlayerCoords

toSet :: (Ord a) => Vector a -> Set a
toSet = S.fromList . V.toList

onBoard :: Vector (Location, a) -> Vector a
onBoard xs = V.map snd $ V.filter (\(l, _) -> l == Board) xs

orangeMoves :: GameState -> Coordinate -> [Placement]
orangeMoves state c = placement0 <$> S.toList (boardRim state `S.intersection` adjCoords c)

purpleMoves :: GameState -> Coordinate -> [Placement]
purpleMoves state coord = adjGround <> adjOnTopPlacements
 where
  adj = adjCoords coord
  placed = onBoard $ V.zip (locations state) $ V.zip (coordinates state) (heights state)
  adjOnTop = do
    c <- V.fromList $ S.toList adj
    let adjPlaced = V.filter (\(x, _) -> x == c) placed
    guard $ (not . V.null) adjPlaced
    pure $ V.maximumOn snd adjPlaced
  adjOnTopPlacements = V.toList $ V.map (\(c, Height h) -> placementH (Height (h + 1)) c) adjOnTop
  adjGround = placement0 <$> (S.toList $ boardRim state `S.intersection` adj)

-- adjPieces = S.map (\x -> V.filter (\(y, _) -> x == y) placed) adj
-- adjTopPieces = S.toList $ S.map (\(x, h) -> placementH h x) $ S.map (V.maximumBy (\(_, x) (_, y) -> compare x y)) $ S.filter null adjPieces

greenMoves :: GameState -> Coordinate -> [Placement]
greenMoves state coord = placement0 <$> S.toList validFrees
 where
  ps = placedCoords state
  adjs = adjCoords coord
  ray c d = let next = step d c in next : ray next d
  allRays = map (ray coord) allDirections
  firstFree [] = error "Ray should be infinite"
  firstFree (x : xs)
    | x `elem` ps = firstFree xs
    | otherwise = x
  allFirstFree = map firstFree allRays
  validFrees = (boardRim state `S.intersection` S.fromList allFirstFree) S.\\ adjs

redMoves :: GameState -> Coordinate -> [Placement]
redMoves state coord = placement0 <$> validMoves
 where
  rim = boardRim state
  placed = placedCoords state
  placedOther = S.delete coord placed
  oneStep c = (adjCoords c `S.intersection` rim) S.\\ placed
  validMoves = do
    step1 <- S.toList $ oneStep coord S.\\ S.fromList [coord]
    guard (isConnected $ S.insert step1 placedOther)
    step2 <- S.toList $ oneStep step1 S.\\ S.fromList [step1, coord]
    guard (isConnected $ S.insert step2 placedOther)
    step3 <- S.toList $ oneStep step2 S.\\ S.fromList [step2, step1, coord]
    guard (isConnected $ S.insert step3 placedOther)
    -- _ <- traceShowId [coord, step1, step2, step3]
    pure step3

isConnected :: Set Coordinate -> Bool
isConnected cs = isConnectedIter (S.take 1 cs) cs
 where
  isConnectedIter visited rest
    | S.null rest = True
    | otherwise =
        let nexts = adjacents visited `S.intersection` rest
         in if S.null nexts then False else isConnectedIter (visited `S.union` nexts) (rest S.\\ nexts)

  adjacents xs = S.unions $ S.map adjCoords xs
