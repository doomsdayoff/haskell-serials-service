{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.IO

import Serials.Query
import Serials.Storage (openStore, readCatalog)
import Serials.Types
import Text.Read (readMaybe)

main :: IO ()
main = do
  -- Без этого кириллица в консоли Windows превращается в мусор.
  mapM_ (\h -> hSetEncoding h utf8) [stdin, stdout, stderr]
  opened <- openStore "serials.json"
  case opened of
    Left err -> hPutStrLn stderr ("Не удалось прочитать serials.json: " ++ err)
    Right store -> do
      catalog <- readCatalog store
      if null catalog
        then TIO.putStrLn "Каталог пуст, работать не с чем."
        else do
          TIO.putStrLn ("Каталог сериалов, записей: " <> tshow (length catalog))
          loop catalog catalog

-- Второй аргумент — текущая выборка: её показывает и сортирует пункт 3.
loop :: [Serial] -> [Serial] -> IO ()
loop catalog selection = do
  TIO.putStrLn ""
  TIO.putStrLn "1 — показать все сериалы"
  TIO.putStrLn "2 — отобрать по критерию"
  TIO.putStrLn "3 — отсортировать текущую выборку"
  TIO.putStrLn "4 — найти сериал"
  TIO.putStrLn "5 — выход"
  choice <- askIndex "> " 5
  case choice of
    1 -> do
      mapM_ (TIO.putStrLn . title) catalog
      loop catalog catalog
    2 -> selectByCriterion catalog >>= loop catalog
    3 -> sortSelection selection >>= loop catalog
    4 -> findSerial catalog >>= loop catalog
    _ -> TIO.putStrLn "Выход."

selectByCriterion :: [Serial] -> IO [Serial]
selectByCriterion catalog = do
  TIO.putStrLn "1 — жанр, 2 — актёр, 3 — режиссёр"
  choice <- askIndex "> " 3
  let (label, values, narrow) = case choice of
        1 -> ("жанры",     genres catalog,     \v -> filterSerials (Just v) Nothing Nothing)
        2 -> ("актёры",    actorNames catalog, \v -> filterSerials Nothing (Just v) Nothing)
        _ -> ("режиссёры", directors catalog,  \v -> filterSerials Nothing Nothing (Just v))
  TIO.putStrLn ("Доступные " <> label <> ":")
  mapM_ TIO.putStrLn (zipWith numbered [1 :: Int ..] values)
  idx <- askIndex "> " (length values)
  let found = narrow (values !! (idx - 1)) catalog
  report found
  return found

sortSelection :: [Serial] -> IO [Serial]
sortSelection [] = do
  TIO.putStrLn "Выборка пуста, сортировать нечего."
  return []
sortSelection selection = do
  TIO.putStrLn "1 — по рейтингу, 2 — по году"
  field <- askIndex "> " 2
  TIO.putStrLn "1 — по возрастанию, 2 — по убыванию"
  order <- askIndex "> " 2
  let sorted = sortSerials (if field == 1 then ByRating else ByYear)
                           (if order == 1 then Asc else Desc)
                           selection
  report sorted
  return sorted

findSerial :: [Serial] -> IO [Serial]
findSerial catalog = do
  query <- ask "Название, режиссёр или год: "
  let found = search query catalog
  report found
  return found

report :: [Serial] -> IO ()
report []    = TIO.putStrLn "Ничего не нашлось."
report found = mapM_ (TIO.putStrLn . describe) found

describe :: Serial -> Text
describe s = T.intercalate "\n"
  [ title s <> " (" <> tshow (year s) <> ")"
  , "  жанр: " <> T.intercalate ", " (genre s)
  , "  актёры: " <> T.intercalate ", " (actors s)
  , "  режиссёр: " <> director s <> ", " <> country s
  , "  рейтинг: " <> tshow (rating s)
      <> ", сезонов: " <> tshow (seasons s)
      <> ", серия " <> tshow (duration s) <> " мин"
  ]

numbered :: Int -> Text -> Text
numbered i value = tshow i <> ". " <> value

ask :: Text -> IO Text
ask prompt = do
  TIO.putStr prompt
  hFlush stdout
  TIO.getLine

askIndex :: Text -> Int -> IO Int
askIndex prompt bound = do
  answer <- readMaybe . T.unpack <$> ask prompt
  case answer of
    Just n | n >= 1, n <= bound -> return n
    _ -> do
      TIO.putStrLn ("Нужно число от 1 до " <> tshow bound <> ".")
      askIndex prompt bound

tshow :: Show a => a -> Text
tshow = T.pack . show
