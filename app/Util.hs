module Util where

echo :: String -> IO ()
echo s = putStrLn $ "INFO: " <> s

bug :: (Show a) => a -> b
bug x = error $ "BUG: " <> (show x)
