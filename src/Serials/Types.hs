{-# LANGUAGE DeriveGeneric #-}

module Serials.Types
  ( Serial (..)
  , loadSerials
  ) where

import Data.Aeson (FromJSON, eitherDecode)
import qualified Data.ByteString.Lazy as BL
import GHC.Generics (Generic)

data Serial = Serial
  { title    :: String
  , genre    :: [String]
  , actors   :: [String]
  , director :: String
  , country  :: String
  , year     :: Int
  , rating   :: Float
  , duration :: Int
  , seasons  :: Int
  } deriving (Show, Eq, Generic)

instance FromJSON Serial

-- Имена полей Serial совпадают с ключами JSON, поэтому разбор целиком
-- выводится из Generic и отдельный парсер не нужен.
loadSerials :: FilePath -> IO (Either String [Serial])
loadSerials path = eitherDecode <$> BL.readFile path
