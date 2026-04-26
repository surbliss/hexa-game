{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Main (main) where

import Data.Text (Text, pack)
import Network.WebSockets

sendHello :: PendingConnection -> IO ()
sendHello p = do
  c <- acceptRequest p
  (resp :: Text) <- receiveData c
  print resp
  sendTextData c (pack "hello mr bajar")

main :: IO ()
main = do
  runServer "localhost" 9000 sendHello
