-- Server-interface
module GenServer (
  Chan,
  Server,
  dupChan,
  writeChan,
  readChan,
  serverSend,
  spawn,
  ReplyChan,
  requestReply,
  serverReply,
  newChan,
  forkIO,
  killThread,
  threadDelay,
  ThreadId,
)
where

import Control.Concurrent (
  Chan,
  ThreadId,
  dupChan,
  forkIO,
  killThread,
  newChan,
  readChan,
  threadDelay,
  writeChan,
 )

data Server msg = Server ThreadId (Chan msg)

newtype ReplyChan a = ReplyChan (Chan a) deriving (Eq)
instance Show (ReplyChan a) where
  show (ReplyChan _) = "ReplyChan (..)"

spawn :: (Chan a -> IO ()) -> IO (Server a)
spawn serverLoop = do
  input <- newChan
  tid <- forkIO $ serverLoop input
  return $ Server tid input

serverSend :: Server a -> a -> IO ()
serverSend (Server _tid input) msg = writeChan input msg

serverReply :: ReplyChan a -> a -> IO ()
serverReply (ReplyChan chan) x = writeChan chan x

requestReply :: Server a -> (ReplyChan b -> a) -> IO b
requestReply serv con = do
  reply_chan <- newChan
  serverSend serv $ con $ ReplyChan reply_chan
  readChan reply_chan
