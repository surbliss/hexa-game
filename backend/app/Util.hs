module Util where

echo :: String -> IO ()
echo s = putStrLn $ "INFO: " <> s

warn :: String -> IO ()
warn s = putStrLn $ "WARN: " <> s

bug :: (Show a) => a -> b
bug x = error $ "BUG: " <> (show x)
