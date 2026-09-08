{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Serials.Types
  ( Serial (..)
  , Health (..)
  , ReloadResult (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

-- Поля строгие: каталог целиком лежит в памяти, и держать в нём
-- нераскрытые санки от разбора JSON смысла нет.
data Serial = Serial
  { title    :: !Text
  , genre    :: ![Text]
  , actors   :: ![Text]
  , director :: !Text
  , country  :: !Text
  , year     :: !Int
  , rating   :: !Double
  , duration :: !Int
  , seasons  :: !Int
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

newtype Health = Health { status :: Text }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

newtype ReloadResult = ReloadResult { loaded :: Int }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)
