{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import System.Exit (exitFailure)
import Test.HUnit

import Serials.Query
import Serials.Storage (openStore, readCatalog)
import Serials.Types

-- Страна, длительность и число сезонов в тестах не участвуют,
-- поэтому фиксируем их значениями по умолчанию.
serial :: Text -> [Text] -> [Text] -> Text -> Int -> Double -> Serial
serial t gs as d y r = Serial
  { title    = t
  , genre    = gs
  , actors   = as
  , director = d
  , country  = "USA"
  , year     = y
  , rating   = r
  , duration = 45
  , seasons  = 1
  }

catalog :: [Serial]
catalog =
  [ serial "Breaking Bad"     ["Drama", "Crime"] ["Bryan Cranston", "Aaron Paul"] "Vince Gilligan" 2008 9.5
  , serial "Friends"          ["Comedy"]         ["Jennifer Aniston"]             "Kevin Bright"   1994 8.9
  , serial "The Office"       ["Comedy"]         ["Steve Carell"]                 "Greg Daniels"   2005 9.0
  , serial "Better Call Saul" ["Drama", "Crime"] ["Bob Odenkirk"]                 "Vince Gilligan" 2015 8.9
  ]

titles :: [Serial] -> [Text]
titles = map title

byGenre :: Text -> [Serial] -> [Serial]
byGenre g = filterSerials (Just g) Nothing Nothing

filterTests :: Test
filterTests = TestLabel "фильтрация" $ TestList
  [ TestCase $ assertEqual "жанр Drama"
      ["Breaking Bad", "Better Call Saul"] (titles (byGenre "Drama" catalog))
  , TestCase $ assertEqual "порядок каталога сохраняется"
      ["Friends", "The Office"] (titles (byGenre "Comedy" catalog))
  , TestCase $ assertEqual "неизвестный жанр даёт пустой список"
      [] (titles (byGenre "Western" catalog))
  , TestCase $ assertEqual "регистр значения не важен"
      ["Friends", "The Office"] (titles (byGenre "comedy" catalog))
  , TestCase $ assertEqual "без параметров возвращается весь каталог"
      (titles catalog) (titles (filterSerials Nothing Nothing Nothing catalog))
  , TestCase $ assertEqual "критерии складываются, а не заменяют друг друга"
      ["Better Call Saul"]
      (titles (filterSerials (Just "Crime") (Just "Bob Odenkirk") (Just "Vince Gilligan") catalog))
  , TestCase $ assertEqual "несовместимые критерии дают пустой список"
      []
      (titles (filterSerials (Just "Comedy") Nothing (Just "Vince Gilligan") catalog))
  ]

sortTests :: Test
sortTests = TestLabel "сортировка" $ TestList
  [ TestCase $ assertEqual "рейтинг по убыванию"
      ["Breaking Bad", "The Office", "Friends", "Better Call Saul"]
      (titles (sortSerials ByRating Desc catalog))
  , TestCase $ assertEqual "равные рейтинги сохраняют исходный порядок"
      ["Friends", "Better Call Saul"]
      (drop 2 (titles (sortSerials ByRating Desc catalog)))
  , TestCase $ assertEqual "год по возрастанию"
      ["Friends", "The Office", "Breaking Bad", "Better Call Saul"]
      (titles (sortSerials ByYear Asc catalog))
  ]

paramTests :: Test
paramTests = TestLabel "разбор параметров" $ TestList
  [ TestCase $ assertEqual "by=rating"       (Just ByRating) (parseSortField "rating")
  , TestCase $ assertEqual "by=YEAR"         (Just ByYear)   (parseSortField "YEAR")
  , TestCase $ assertEqual "by=имя_поля"     Nothing         (parseSortField "duration")
  , TestCase $ assertEqual "order=asc"       (Just Asc)      (parseSortOrder "asc")
  , TestCase $ assertEqual "order=Desc"      (Just Desc)     (parseSortOrder "Desc")
  , TestCase $ assertEqual "order=случайное" Nothing         (parseSortOrder "up")
  ]

lookupTests :: Test
lookupTests = TestLabel "поиск" $ TestList
  [ TestCase $ assertEqual "регистр не важен"
      ["Breaking Bad"] (titles (search "breaking" catalog))
  , TestCase $ assertEqual "находит по режиссёру"
      ["Breaking Bad", "Better Call Saul"] (titles (search "Gilligan" catalog))
  , TestCase $ assertEqual "находит по году"
      ["The Office"] (titles (search "2005" catalog))
  , TestCase $ assertEqual "ничего не найдено"
      [] (titles (search "Lost" catalog))
  , TestCase $ assertEqual "точное название"
      (Just "The Office") (title <$> findByTitle "the office" catalog)
  , TestCase $ assertEqual "частичное название не подходит"
      Nothing (title <$> findByTitle "Office" catalog)
  ]

listTests :: Test
listTests = TestLabel "справочники" $ TestList
  [ TestCase $ assertEqual "жанры без повторов и по алфавиту"
      ["Comedy", "Crime", "Drama"] (genres catalog)
  , TestCase $ assertEqual "режиссёры без повторов"
      ["Greg Daniels", "Kevin Bright", "Vince Gilligan"] (directors catalog)
  ]

-- Проверяем не только чистые функции, но и то, что файл каталога
-- вообще разбирается текущей структурой Serial.
storeTest :: Test
storeTest = TestLabel "serials.json" $ TestCase $ do
  opened <- openStore "serials.json"
  case opened of
    Left err -> assertFailure ("файл не разобран: " ++ err)
    Right store -> do
      rows <- readCatalog store
      assertBool "каталог не должен быть пустым" (not (null rows))

main :: IO ()
main = do
  result <- runTestTT $ TestList
    [ filterTests, sortTests, paramTests, lookupTests, listTests, storeTest ]
  unless (errors result == 0 && failures result == 0) exitFailure
