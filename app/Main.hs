{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Main (main) where

import Data.List (intersect, (\\))
import Data.Text (pack)
import Network.WebSockets

---------------------------------------------------
-- The board
---------------------------------------------------
-- See https://en.wikipedia.org/wiki/Hexagonal_Efficient_Coordinate_System for info about hexagonal coordinate-system

-- If sub-hex-array is shifted to the left or right
data Shift = U | D deriving (Show, Eq)
newtype Coordinate = Coord (Shift, Int, Int) deriving (Eq, Show)

-- x +1 when going U -> D

neighbours :: Coordinate -> [Coordinate]
neighbours (Coord (s, c, r)) =
  [Coord (s, c, r') | r' <- [r - 1, r + 1]] ++ [Coord (s', c', r') | r' <- rs, c' <- cs]
 where
  s' = case s of
    U -> D
    D -> U
  (cs, rs) = case s of
    U -> ([c, c + 1], [r, r + 1])
    D -> ([c - 1, c], [r - 1, r])

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

-- For testing
exampleHive :: Hive
exampleHive =
  Hive
    [ (Coord (U, 0, 2), B, North)
    , (Coord (U, 0, 1), V, North)
    , (Coord (D, 1, 2), C, South)
    , (Coord (U, 1, 2), P, North)
    , (Coord (U, 1, 1), G, South)
    , (Coord (U, 1, 0), G, North)
    , (Coord (D, 2, 0), P, South)
    ]

sendHello :: PendingConnection -> IO ()
sendHello p = do
  c <- acceptRequest p
  sendTextData c (pack "hello mr bajar")

main :: IO ()
main = do
  runServer "localhost" 9000 sendHello
