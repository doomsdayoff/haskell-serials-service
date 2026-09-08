{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Serials.API
  ( API
  , SerialsAPI
  , api
  ) where

import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Servant.API

import Serials.Types (Health, ReloadResult, Serial)

type API = "api" :> "v1" :>
  (    "health"  :> Get '[JSON] Health
  :<|> "serials" :> SerialsAPI
  )

-- Статические сегменты идут раньше Capture: иначе /serials/filter
-- разобрался бы как запрос сериала с названием "filter".
type SerialsAPI =
       Get '[JSON] [Serial]
  :<|> "filter" :> QueryParam "genre"    Text
                :> QueryParam "actor"    Text
                :> QueryParam "director" Text
                :> Get '[JSON] [Serial]
  :<|> "sort"   :> QueryParam "by"    Text
                :> QueryParam "order" Text
                :> Get '[JSON] [Serial]
  :<|> "search" :> QueryParam "query" Text
                :> Get '[JSON] [Serial]
  :<|> "reload" :> Post '[JSON] ReloadResult
  :<|> Capture "title" Text :> Get '[JSON] Serial

api :: Proxy API
api = Proxy
