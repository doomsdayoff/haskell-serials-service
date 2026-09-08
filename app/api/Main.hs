module Main (main) where

import Data.Maybe (fromMaybe)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.RequestLogger (logStdout)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.IO (BufferMode (LineBuffering), hSetBuffering, stdout)
import Text.Read (readMaybe)

import Serials.Server (app)
import Serials.Storage (openStore, readCatalog)

main :: IO ()
main = do
  -- В контейнере stdout не терминал и по умолчанию буферизуется поблочно,
  -- из-за чего логи появляются пачками или теряются при падении.
  hSetBuffering stdout LineBuffering
  path <- envOr "SERIALS_DATA" "serials.json"
  port <- fromMaybe 8080 . (>>= readMaybe) <$> lookupEnv "PORT"
  opened <- openStore path
  store <- either (\err -> die (path ++ ": " ++ err)) return opened
  size <- length <$> readCatalog store
  putStrLn ("catalog loaded: " ++ show size ++ " serials from " ++ path)
  putStrLn ("listening on http://localhost:" ++ show port)
  run port (logStdout (app store))

envOr :: String -> String -> IO String
envOr name fallback = fromMaybe fallback <$> lookupEnv name
