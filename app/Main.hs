module Main (main) where

import GenServer
import Network.WebSockets
import Socket

main :: IO ()
main = do
  gameState <- initGameState
  gameServer <- spawn (handleServerMessage gameState)
  runServer "localhost" 9000 (socketApp gameServer)
