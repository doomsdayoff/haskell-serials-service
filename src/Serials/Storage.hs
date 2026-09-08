module Serials.Storage
  ( Store
  , openStore
  , readCatalog
  , reloadCatalog
  ) where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVarIO, writeTVar)
import Data.Aeson (eitherDecodeFileStrict')

import Serials.Types (Serial)

-- Каталог небольшой и целиком помещается в память. TVar здесь нужен не ради
-- конкурентной записи, а чтобы reloadCatalog подменял каталог одним шагом:
-- параллельные запросы видят либо старую версию, либо новую, но не половину.
data Store = Store
  { storePath    :: FilePath
  , storeCatalog :: TVar [Serial]
  }

openStore :: FilePath -> IO (Either String Store)
openStore path = do
  parsed <- eitherDecodeFileStrict' path
  traverse (fmap (Store path) . newTVarIO) parsed

readCatalog :: Store -> IO [Serial]
readCatalog = readTVarIO . storeCatalog

-- Битый файл оставляет в памяти прежний каталог, сервис продолжает отвечать.
reloadCatalog :: Store -> IO (Either String Int)
reloadCatalog store = do
  parsed <- eitherDecodeFileStrict' (storePath store)
  traverse install parsed
  where
    install catalog = do
      atomically (writeTVar (storeCatalog store) catalog)
      return (length catalog)
