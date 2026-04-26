module Game where

import Data.List (intersect, (\\))

---------------------------------------------------
-- The board
---------------------------------------------------
-- See https://en.wikipedia.org/wiki/Hexagonal_Efficient_Coordinate_System for info about hexagonal coordinate-system

-- Coordinate: Y-coordinate points up, X-coordinate 60 degree north-east from Y
newtype Coordinate = Coord (Int, Int) deriving (Eq, Show)
data Direction = U | D | UR | DR | UL | DL deriving (Eq, Show)

step :: Direction -> Coordinate -> Coordinate
step dir (Coord (x, y)) = Coord $ case dir of
  U -> (x, y + 1)
  D -> (x, y - 1)
  UR -> (x + 1, y)
  DR -> (x + 1, y - 1)
  UL -> (x - 1, y + 1)
  DL -> (x - 1, y - 1)

neighbours :: Coordinate -> [Coordinate]
neighbours c = map (\d -> step d c) [U, D, UR, DR, UL, DL]

data Alignment = North | South deriving (Eq, Show)

newtype Hive = Hive [(Coordinate, Piece, Alignment)] deriving (Eq, Show)

coordinates :: Hive -> [Coordinate]
coordinates (Hive xs) = map (\(c, _, _) -> c) xs

isConnected :: [Coordinate] -> Bool
isConnected cs = and [any (`elem` cs) ns | ns <- map neighbours cs]

---------------------------------------------------
-- Pieces
---------------------------------------------------
data Piece
  = G -- queen
  | P -- hopper
  | C -- soldier
  | V -- Spider
  | B -- Beetle
  deriving (Eq, Show)

legalMoves :: Piece -> Hive -> Coordinate -> [Coordinate]
legalMoves G h c = neighbours c \\ coordinates h
legalMoves B h c = neighbours c `intersect` coordinates h
legalMoves _ _ _ = undefined

testBoard :: [Coordinate]
testBoard =
  map
    Coord
    [ (1, 1)
    , (-1, 1)
    , (0, 1)
    , (3, 3)
    ]

-- -- For testing
-- exampleHive :: Hive
-- exampleHive =
--   Hive
--     [ (Coord (U, 0, 2), B, North)
--     , (Coord (U, 0, 1), V, North)
--     , (Coord (D, 1, 2), C, South)
--     , (Coord (U, 1, 2), P, North)
--     , (Coord (U, 1, 1), G, South)
--     , (Coord (U, 1, 0), G, North)
--     , (Coord (D, 2, 0), P, South)
--     ]
