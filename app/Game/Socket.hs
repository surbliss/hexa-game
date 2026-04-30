{-# LANGUAGE OverloadedStrings #-}

module Game.Socket (socketApp) where

import Control.Monad (forever)
import Data.Text (Text, splitOn, unpack)
import Game.Protocol (
  ClientMessage (CInitPlayer),
  GameServer,
  ServerMessage (SRegisterPlayer),
  encode,
  parseServerMessage,
 )
import GenServer
import Network.WebSockets (
  PendingConnection,
  acceptRequest,
  receiveData,
  sendTextData,
 )
import Util

--- Socket loop (one loop for each device connected)
socketApp :: GameServer -> PendingConnection -> IO ()
socketApp gameServer pendingConnection = do
  con <- acceptRequest pendingConnection
  -- Get player info (must be 'connect ...')
  text <- receiveData con
  (outChan, player, pieces) <- case splitOn " " text of
    ["connect", token] -> requestReply gameServer $ SRegisterPlayer $ unpack token
    _ -> bug text
  _ <- forkIO $ forever $ do
    msg <- readChan outChan
    echo $ "receiving: " <> show msg
    sendTextData con (encode msg)
  sendTextData con (encode $ CInitPlayer player pieces)
  forever $ do
    (msg :: Text) <- receiveData con
    echo $ "sending: " <> show msg
    serverSend gameServer (parseServerMessage player msg)
