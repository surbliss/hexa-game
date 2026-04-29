module Main (main) where

import GenServer
import Network.WebSockets
import Socket

main :: IO ()
main = do
  gameState <- initGameState
  gameServer <- spawn (handleServerMessage gameState)
  runServer "0.0.0.0" 9000 (socketApp gameServer)
