module Main (main) where

import Game.Server (initGameServer)
import Game.Socket (socketApp)
import Network.WebSockets (runServer)

main :: IO ()
main = do
  gameServer <- initGameServer
  runServer "0.0.0.0" 9000 (socketApp gameServer)
