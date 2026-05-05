{-# OPTIONS_GHC -Wno-unused-imports #-}

module Game.Logic (
  GameState,
  RenderPosition,
  initialGameState,
  legalMoves,
  movePiece,
  boardRenderPositions,
) where

import Control.Exception (assert)
import Control.Monad (guard)
import Data.List.NonEmpty (NonEmpty ((:|)), (<|))
import Data.List.NonEmpty qualified as NE
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as M
import Data.Set (Set, (\\))
import Data.Set qualified as S
import Data.Vector (Vector, (!), (//))
import Data.Vector qualified as V
import Debug.Trace (trace, traceShowId)
import Game.Protocol (PieceId, RenderPosition (..))

---------------------------------------------------
-- Data-types
---------------------------------------------------
--- Exported datatypes

-- | All the info about gamestate, that changes throughout. Constructors _not_ exported
type Stacks = Map Coordinate (NonEmpty PieceId)

data GameState = GameState
  { getPieces :: Vector (Maybe Coordinate)
  , getStacks :: Stacks
  , currentPlayer :: Player
  , currentTurn :: Int
  }

--- Internal datatypes
data Direction = U | D | UR | DR | UL | DL deriving (Eq, Show, Ord)

-- Combined piece-state
newtype Coordinate = Coordinate (Int, Int) deriving (Eq, Show, Ord)

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
-- Public functions
---------------------------------------------------
initialGameState :: GameState
initialGameState =
  GameState
    { getPieces = V.replicate 22 Nothing
    , getStacks = M.empty
    , currentPlayer = Player1
    , currentTurn = 1
    }

boardRenderPositions :: GameState -> [Maybe RenderPosition]
boardRenderPositions state = V.toList $ V.map (fmap renderPos) (getPieces state)
 where
  renderPos c@(Coordinate (x, y)) = RenderPosition (x, y, height (getStacks state) c)

movePiece :: PieceId -> (Int, Int) -> GameState -> GameState
movePiece i (x, y) state =
  assert
    (any (\(RenderPosition (x', y', _)) -> x' == x && y' == y) (legalMoves state i))
    state
      { getPieces = getPieces state // [(i, Just newC)]
      , getStacks = newStacks
      , currentPlayer = nextPlayer
      , currentTurn = nextTurn
      }
 where
  newC = Coordinate (x, y)
  oldC = getPieces state ! i -- Maybe Coordinate
  stacks = getStacks state
  transitStacks = case oldC of
    Nothing -> stacks
    Just c -> popStack c stacks
  newStacks = pushStack i newC transitStacks
  (nextPlayer, nextTurn) = case (currentPlayer state) of
    Player1 -> (Player2, currentTurn state)
    Player2 -> (Player1, currentTurn state + 1)

-- Note: Export stuff as _lists_ to avoid Vector-dependency when importing
-- Also, use 'RenderPosition' from Protocol module, so Server does not have to look at internals of Logic when sending game-info
legalMoves :: GameState -> PieceId -> [RenderPosition]
legalMoves state i
  | currentPlayer state /= pieceOwner i = [] -- Current player has to own the piece
  | otherwise = case ( currentTurn state
                     , currentPlayer state
                     , getPieces state ! i
                     , pieceKinds ! i
                     ) of
      (1, _, _, Orange) -> [] -- No queen in first move, for either player
      (1, Player1, _, _) -> [RenderPosition (0, 0, 0)] -- Always start in center
      (1, Player2, _, _) ->
        [ RenderPosition (x, y, 0)
        | d <- allDirections
        , let Coordinate (x, y) = step d (Coordinate (0, 0))
        ]
      -- Special case for first move for Player 2 (in other cases, the player is not allowed to place next to opposing pieces)      (_, _, Just _, _) | orangeIsInStock state -> [] -- Can't move pieces on board before queen is placed
      (4, _, Nothing, k) | k /= Orange && orangeIsInStock state -> [] -- Queen has to be placed by turn 4 latest
      (_, _, Nothing, _) -> map placement0 $ S.toList $ legalStockMoves state -- If not placed yet, do stock-moves
      -- TODO: Filter these, somehow
      (_, _, Just c, k)
        | i /= NE.head (getStacks state M.! c) -> [] -- Piece not on top of its stack
        | otherwise -> legalBoardMoves (getStacks state) c k

---------------------------------------------------
-- Private helper-functions
---------------------------------------------------

allDirections :: [Direction]
allDirections = [U, D, UR, DR, UL, DL]

pushStack :: PieceId -> Coordinate -> Stacks -> Stacks
pushStack i c stacks = newStacks
 where
  f Nothing = Just (i :| [])
  f (Just s) = Just (i <| s)
  newStacks = M.alter f c stacks

-- | Takes 'Maybe Coordinate' as a convinience: Allows passing pieces directly, without first checking if they are in stock or on board
popStack :: Coordinate -> Stacks -> Stacks
popStack c stacks = newStacks
 where
  f Nothing = error "Stack should not be empty when piece is on the board"
  f (Just (_ :| [])) = Nothing
  f (Just (_ :| y : ys)) = Just (y :| ys)
  newStacks = M.alter f c stacks

-- | Note: When this function is called, the 'Stacks'
legalBoardMoves :: Stacks -> Coordinate -> PieceKind -> [RenderPosition]
legalBoardMoves stacks c k
  | (not . isConnected . board) poppedStacks = [] -- Piece in transit leaves board un-connected
  | otherwise = map renderPosition coords
 where
  poppedStacks = popStack c stacks
  coords = case k of
    Purple -> purpleMoves poppedStacks c
    Orange -> orangeMoves poppedStacks c
    Green -> greenMoves poppedStacks c
    Blue -> blueMoves poppedStacks c
    Red -> redMoves poppedStacks c
  renderPosition c'@(Coordinate (x, y)) =
    RenderPosition (x, y, height poppedStacks c')

orangeIsInStock :: GameState -> Bool
orangeIsInStock state = case (currentPlayer state) of
  Player1 -> getPieces state ! 10 == Nothing
  Player2 -> getPieces state ! 21 == Nothing

--- Piece-movement while on the board, per piece-type
legalStockMoves :: GameState -> Set Coordinate
legalStockMoves state = S.filter onlyFriendlyAdjs rim
 where
  stacks = getStacks state
  rim = boardRim stacks
  tops = NE.head <$> stacks
  adjIds c = M.restrictKeys tops $ adjCoords c
  onlyFriendlyAdjs c = all (\i -> pieceOwner i == currentPlayer state) (adjIds c)

-- If a piece is present, height > 0, otherwise height = 0
height :: Stacks -> Coordinate -> Int
height stacks c = case stacks M.!? c of
  Nothing -> 0
  Just xs -> NE.length xs

board :: Stacks -> Set Coordinate
board = M.keysSet

boardRim :: Stacks -> Set Coordinate
boardRim stacks = adjs \\ ps
 where
  ps = board stacks
  adjs = S.unions $ S.map adjCoords ps

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

step :: Direction -> Coordinate -> Coordinate
step dir (Coordinate (x, y)) = Coordinate $ case dir of
  U -> (x, y + 1)
  D -> (x, y - 1)
  UR -> (x + 1, y)
  DR -> (x + 1, y - 1)
  UL -> (x - 1, y + 1)
  DL -> (x - 1, y)

-- Two coordinates: (+, -) direction, + being counter-clockwise, and - being clockwise
rotate :: Direction -> (Direction, Direction)
rotate U = (UR, UL)
rotate UR = (DR, U)
rotate DR = (UR, D)
rotate D = (DR, DL)
rotate DL = (D, UL)
rotate UL = (U, DL)

-- The 'freedom to move', checks if there is a piece in each direction
-- Note that we are assuming that 'c' refers to the top piece of the stack at c
freeAdjs :: Stacks -> Coordinate -> Set Coordinate
freeAdjs stacks c = S.fromList $ do
  d <- allDirections
  let (r, l) = rotate d
  guard $ M.notMember (step r c) stacks || M.notMember (step l c) stacks
  guard $ M.notMember (step d c) stacks
  pure $ step d c

adjCoords :: Coordinate -> Set Coordinate
adjCoords c = S.fromList $ map (\d -> step d c) allDirections

placement0 :: Coordinate -> RenderPosition
placement0 (Coordinate (x, y)) = RenderPosition (x, y, 0)

{- | Only ground-level steps here. Stack should have coordinate 'popped' already. Requirements:
- No piece where going
- Rotating either left or right from step is empty
- The next step is still adjacent to the board
- Removing the piece does not make the board disconnected
- The resulting coodinate must have one adjacent in common, with adjacents from previours coordinate

See: https://imgur.com/Mc4tJnB

TODO: Also make this function work for beetles (taking height into consideration)
-}
validSteps :: Stacks -> Coordinate -> [Coordinate]
validSteps poppedStacks c =
  assert (M.notMember c poppedStacks) $
    [ x
    | -- We already checked here, that board is connected with c popped!
    x <- S.toList $ free `S.intersection` rim
    , -- Previous and next spot has at least one neighbour in commond
    not $ S.null $ adjCoords c `S.intersection` adjCoords x `S.intersection` bs
    ]
 where
  free = freeAdjs poppedStacks c
  rim = boardRim poppedStacks
  bs = board poppedStacks

orangeMoves :: Stacks -> Coordinate -> [Coordinate]
orangeMoves stacks c = validSteps stacks c

purpleMoves :: Stacks -> Coordinate -> [Coordinate]
purpleMoves stacks c = S.toList $ adjGround <> adjPlaced
 where
  bs = board stacks
  rim = boardRim stacks
  adjs = adjCoords c
  adjPlaced = adjs `S.intersection` bs
  adjGround = adjs `S.intersection` rim

blueMoves :: Stacks -> Coordinate -> [Coordinate]
blueMoves stacks c = S.toList $ blueIter S.empty (S.singleton c) (board stacks)
 where
  blueIter before current remaining
    | S.null current = before
    | S.null remaining = before `S.union` current
    | otherwise =
        blueIter
          (before `S.union` nexts)
          (nexts)
          (remaining \\ nexts)
   where
    nextsAll = S.unions $ S.map (S.fromList . (validSteps stacks)) current
    nexts = (nextsAll \\ before) \\ current

greenMoves :: Stacks -> Coordinate -> [Coordinate]
greenMoves stacks coord = S.toList validFrees
 where
  ps = board stacks
  adjs = adjCoords coord
  ray c d = let next = step d c in next : ray next d
  allRays = map (ray coord) allDirections
  firstFree [] = error "Ray should be infinite"
  firstFree (x : xs)
    | x `elem` ps = firstFree xs
    | otherwise = x

  allFirstFree = map firstFree allRays
  validFrees = (boardRim stacks `S.intersection` S.fromList allFirstFree) \\ adjs

redMoves :: Stacks -> Coordinate -> [Coordinate]
redMoves stacks c =
  [ step3
  | step1 <- validSteps stacks c
  , step1 /= c
  , step2 <- validSteps stacks step1
  , step2 `notElem` [c, step1]
  , step3 <- validSteps stacks step2
  , step3 `notElem` [c, step1, step2]
  ]

-- Check if hexagon-graph is connected with a breadth-first search
isConnected :: Set Coordinate -> Bool
isConnected cs = isConnectedIter (S.take 1 cs) cs
 where
  isConnectedIter current rest
    | S.null rest = True
    | S.null nexts = False
    | otherwise = isConnectedIter nexts (rest \\ nexts)
   where
    nexts = adjacents current `S.intersection` rest
  adjacents xs = S.unions $ S.map adjCoords xs
