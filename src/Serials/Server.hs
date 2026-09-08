{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Serials.Server
  ( app
  , server
  ) where

import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Network.Wai (Application)
import Servant.API ((:<|>) (..))
import Servant.Server (Handler, Server, ServerError (..), err400, err404, serve)

import Serials.API (API, api)
import Serials.Query
import Serials.Storage (Store, readCatalog, reloadCatalog)
import Serials.Types

app :: Store -> Application
app = serve api . server

server :: Store -> Server API
server store =
       health
  :<|> listAll
  :<|> filtered
  :<|> sorted
  :<|> found
  :<|> reload
  :<|> detail
  where
    catalog = liftIO (readCatalog store)

    health = return (Health "ok")

    listAll = catalog

    filtered wantGenre wantActor wantDirector =
      filterSerials wantGenre wantActor wantDirector <$> catalog

    -- Без параметров отдаём самое ожидаемое: топ по рейтингу.
    sorted rawField rawOrder = do
      field <- parseParam "by"    "rating|year" parseSortField (fromMaybe "rating" rawField)
      order <- parseParam "order" "asc|desc"    parseSortOrder (fromMaybe "desc"   rawOrder)
      sortSerials field order <$> catalog

    found rawQuery = case T.strip (fromMaybe "" rawQuery) of
      ""    -> throwError (jsonError err400 "параметр query обязателен и не может быть пустым")
      query -> search query <$> catalog

    reload = do
      result <- liftIO (reloadCatalog store)
      case result of
        Left err -> throwError (jsonError err400 ("каталог не перечитан: " <> T.pack err))
        Right n  -> return (ReloadResult n)

    detail wanted = do
      serials <- catalog
      case findByTitle wanted serials of
        Just serial -> return serial
        Nothing     -> throwError (jsonError err404 ("сериал «" <> wanted <> "» не найден"))

parseParam :: Text -> Text -> (Text -> Maybe a) -> Text -> Handler a
parseParam name allowed parser raw = case parser raw of
  Just value -> return value
  Nothing    -> throwError (jsonError err400 msg)
  where
    msg = name <> "=" <> raw <> ": ожидается одно из " <> allowed

-- Тело ошибки по умолчанию — plain text, а клиент везде ждёт JSON.
jsonError :: ServerError -> Text -> ServerError
jsonError base message = base
  { errBody    = encode (object ["error" .= message])
  , errHeaders = [("Content-Type", "application/json;charset=utf-8")]
  }
