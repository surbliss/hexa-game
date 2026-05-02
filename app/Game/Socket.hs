{-# LANGUAGE OverloadedStrings #-}

module Game.Socket (socketApp) where

import Control.Monad (forever)
import Data.Text (Text)
import Data.Text qualified as T
import Game.Protocol (
  ClientKind (..),
  ClientMessage (CInitPlayer),
  GameServer,
  ServerMessage (SRegisterClient),
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
  (outChan, client, pieces) <- case T.splitOn " " text of
    ["connect", token] -> requestReply gameServer $ SRegisterClient $ getClientKind token
    _ -> bug text
  _ <- forkIO $ forever $ do
    msg <- readChan outChan
    echo $ "receiving: " <> show msg
    sendTextData con (encode msg)
  sendTextData con (encode $ CInitPlayer client pieces)
  forever $ do
    (msg :: Text) <- receiveData con
    echo $ "sending: " <> show msg
    serverSend gameServer (parseServerMessage client msg)

getClientKind :: Text -> Maybe ClientKind
getClientKind "new" = Nothing
getClientKind "1" = Just ActiveClient1
getClientKind "2" = Just ActiveClient2
getClientKind "s" = Just Spectator
getClientKind other = error $ "Invalid player token: " <> T.unpack other
