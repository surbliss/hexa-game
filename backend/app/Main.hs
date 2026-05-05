module Main (main) where

import Game.Server (initServer)
import Game.Socket (socketApp)
import Network.WebSockets (runServer)

main :: IO ()
main = do
  putStrLn ""
  putStrLn "BACKEND SERVER RUNNING"
  putStrLn "======================"
  gameServer <- initServer
  runServer "0.0.0.0" 9000 (socketApp gameServer)
