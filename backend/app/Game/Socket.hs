{-# LANGUAGE OverloadedStrings #-}

module Game.Socket (socketApp) where

import Control.Exception (catch)
import Control.Exception.Base (SomeException)
import Control.Monad (forever)
import Data.Text (Text)
import Data.Text qualified as T
import Game.Protocol (
  ClientMessage (CInitPlayer),
  ClientRole (..),
  GameServer,
  ServerMessage (SRegisterClient, SUnregisterClient),
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
  -- Get player info (their first message must be 'connect <token>')
  text <- receiveData con
  (outChan, client, turn, pieces) <- case T.splitOn " " text of
    ["connect", token] -> requestReply gameServer $ SRegisterClient $ getClientKind token
    _ -> bug text
  _ <- forkIO $ forever $ do
    msg <- readChan outChan
    echo $ "receiving: " <> show msg
    sendTextData con (encode msg)
  sendTextData con (encode $ CInitPlayer client turn pieces)
  let
    socketLoop = do
      (msg :: Text) <- receiveData con
      echo $ "sending: " <> show msg
      serverSend gameServer (parseServerMessage client msg)
    handleConnectionClose :: SomeException -> IO ()
    handleConnectionClose e = do
      warn $ "Client closed due to exception: " <> show e
      serverSend gameServer $ SUnregisterClient client
  forever socketLoop `catch` handleConnectionClose

getClientKind :: Text -> Maybe ClientRole
getClientKind "new" = Nothing
getClientKind "1" = Just ActiveClient1
getClientKind "2" = Just ActiveClient2
getClientKind "s" = Just Spectator
getClientKind other = error $ "Invalid player token: " <> T.unpack other
