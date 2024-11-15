module Main (main) where

import Control.Monad (unless)
import System.Exit (exitFailure)
import Test.HUnit

import Serials.Query
import Serials.Types

-- Страна, длительность и число сезонов в тестах не участвуют,
-- поэтому фиксируем их значениями по умолчанию.
serial :: String -> [String] -> [String] -> String -> Int -> Float -> Serial
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
  [ serial "Breaking Bad" ["Drama", "Crime"] ["Bryan Cranston", "Aaron Paul"] "Vince Gilligan" 2008 9.5
  , serial "Friends"      ["Comedy"]         ["Jennifer Aniston"]             "Kevin Bright"   1994 8.9
  , serial "The Office"   ["Comedy"]         ["Steve Carell"]                 "Greg Daniels"   2005 9.0
  ]

titles :: [Serial] -> [String]
titles = map title

filterTests :: Test
filterTests = TestLabel "фильтрация" $ TestList
  [ TestCase $ assertEqual "один сериал в жанре Drama"
      ["Breaking Bad"] (titles (filterByGenre "Drama" catalog))
  , TestCase $ assertEqual "порядок каталога сохраняется"
      ["Friends", "The Office"] (titles (filterByGenre "Comedy" catalog))
  , TestCase $ assertEqual "неизвестный жанр даёт пустой список"
      [] (titles (filterByGenre "Western" catalog))
  , TestCase $ assertEqual "фильтр по актёру"
      ["Breaking Bad"] (titles (filterByActor "Aaron Paul" catalog))
  , TestCase $ assertEqual "фильтр по режиссёру"
      ["The Office"] (titles (filterByDirector "Greg Daniels" catalog))
  ]

sortTests :: Test
sortTests = TestLabel "сортировка" $ TestList
  [ TestCase $ assertEqual "рейтинг по убыванию"
      ["Breaking Bad", "The Office", "Friends"]
      (titles (sortSerials ByRating Desc catalog))
  , TestCase $ assertEqual "рейтинг по возрастанию"
      ["Friends", "The Office", "Breaking Bad"]
      (titles (sortSerials ByRating Asc catalog))
  , TestCase $ assertEqual "год по возрастанию"
      ["Friends", "The Office", "Breaking Bad"]
      (titles (sortSerials ByYear Asc catalog))
  ]

searchTests :: Test
searchTests = TestLabel "поиск" $ TestList
  [ TestCase $ assertEqual "регистр не важен"
      ["Breaking Bad"] (titles (search "breaking" catalog))
  , TestCase $ assertEqual "находит по режиссёру"
      ["Friends"] (titles (search "Kevin" catalog))
  , TestCase $ assertEqual "находит по году"
      ["The Office"] (titles (search "2005" catalog))
  , TestCase $ assertEqual "пустой результат"
      [] (titles (search "Lost" catalog))
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
dataFileTest :: Test
dataFileTest = TestLabel "serials.json" $ TestCase $ do
  loaded <- loadSerials "serials.json"
  case loaded of
    Left err   -> assertFailure ("файл не разобран: " ++ err)
    Right rows -> assertBool "каталог не должен быть пустым" (not (null rows))

main :: IO ()
main = do
  counts <- runTestTT $ TestList
    [ filterTests, sortTests, searchTests, listTests, dataFileTest ]
  unless (errors counts == 0 && failures counts == 0) exitFailure
