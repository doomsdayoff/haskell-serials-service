module Main (main) where

import Data.List (intercalate)
import System.IO
import Text.Read (readMaybe)

import Serials.Query
import Serials.Types

main :: IO ()
main = do
  -- Без этого кириллица в консоли Windows превращается в мусор.
  mapM_ (\h -> hSetEncoding h utf8) [stdin, stdout, stderr]
  loaded <- loadSerials "serials.json"
  case loaded of
    Left err      -> hPutStrLn stderr ("Не удалось прочитать serials.json: " ++ err)
    Right catalog -> do
      putStrLn ("Каталог сериалов, записей: " ++ show (length catalog))
      loop catalog catalog

-- Второй аргумент — текущая выборка: её показывает и сортирует пункт 3.
loop :: [Serial] -> [Serial] -> IO ()
loop catalog selection = do
  putStrLn ""
  putStrLn "1 — показать все сериалы"
  putStrLn "2 — отобрать по критерию"
  putStrLn "3 — отсортировать текущую выборку"
  putStrLn "4 — найти сериал"
  putStrLn "5 — выход"
  choice <- askIndex "> " 5
  case choice of
    1 -> do
      mapM_ (putStrLn . title) catalog
      loop catalog catalog
    2 -> selectByCriterion catalog >>= loop catalog
    3 -> sortSelection selection >>= loop catalog
    4 -> findSerial catalog >>= loop catalog
    _ -> putStrLn "Выход."

selectByCriterion :: [Serial] -> IO [Serial]
selectByCriterion catalog = do
  putStrLn "1 — жанр, 2 — актёр, 3 — режиссёр"
  choice <- askIndex "> " 3
  let (label, values, keep) = case choice of
        1 -> ("жанры",     genres catalog,     filterByGenre)
        2 -> ("актёры",    actorNames catalog, filterByActor)
        _ -> ("режиссёры", directors catalog,  filterByDirector)
  putStrLn ("Доступные " ++ label ++ ":")
  mapM_ putStrLn (zipWith numbered [1 :: Int ..] values)
  idx <- askIndex "> " (length values)
  let found = keep (values !! (idx - 1)) catalog
  report found
  return found

sortSelection :: [Serial] -> IO [Serial]
sortSelection [] = do
  putStrLn "Выборка пуста, сортировать нечего."
  return []
sortSelection selection = do
  putStrLn "1 — по рейтингу, 2 — по году"
  field <- askIndex "> " 2
  putStrLn "1 — по возрастанию, 2 — по убыванию"
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
report []    = putStrLn "Ничего не нашлось."
report found = mapM_ (putStrLn . describe) found

describe :: Serial -> String
describe s = intercalate "\n"
  [ title s ++ " (" ++ show (year s) ++ ")"
  , "  жанр: " ++ intercalate ", " (genre s)
  , "  актёры: " ++ intercalate ", " (actors s)
  , "  режиссёр: " ++ director s ++ ", " ++ country s
  , "  рейтинг: " ++ show (rating s)
      ++ ", сезонов: " ++ show (seasons s)
      ++ ", серия " ++ show (duration s) ++ " мин"
  ]

numbered :: Int -> String -> String
numbered i value = show i ++ ". " ++ value

ask :: String -> IO String
ask prompt = do
  putStr prompt
  hFlush stdout
  getLine

askIndex :: String -> Int -> IO Int
askIndex prompt bound = do
  answer <- readMaybe <$> ask prompt
  case answer of
    Just n | n >= 1, n <= bound -> return n
    _ -> do
      putStrLn ("Нужно число от 1 до " ++ show bound ++ ".")
      askIndex prompt bound
