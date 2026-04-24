-- Server-interface
module GenServer (
  Chan,
  Server,
  writeChan,
  readChan,
  send,
  spawn,
  ReplyChan,
  requestReply,
  reply,
  forkIO,
  killThread,
  threadDelay,
)
where

import Control.Concurrent (
  Chan,
  ThreadId,
  forkIO,
  killThread,
  newChan,
  readChan,
  threadDelay,
  writeChan,
 )

data Server msg = Server ThreadId (Chan msg)

newtype ReplyChan a = ReplyChan (Chan a)

spawn :: (Chan a -> IO ()) -> IO (Server a)
spawn serverLoop = do
  input <- newChan
  tid <- forkIO $ serverLoop input
  return $ Server tid input

send :: Server a -> a -> IO ()
send (Server _tid input) msg = writeChan input msg

reply :: ReplyChan a -> a -> IO ()
reply (ReplyChan chan) x = writeChan chan x

requestReply :: Server a -> (ReplyChan b -> a) -> IO b
requestReply serv con = do
  reply_chan <- newChan
  send serv $ con $ ReplyChan reply_chan
  readChan reply_chan
