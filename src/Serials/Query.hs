module Serials.Query
  ( SortField (..)
  , SortOrder (..)
  , genres
  , actorNames
  , directors
  , filterByGenre
  , filterByActor
  , filterByDirector
  , sortSerials
  , search
  ) where

import Data.Char (toLower)
import Data.List (isInfixOf, sortOn)
import Data.Ord (Down (..))
import qualified Data.Set as Set

import Serials.Types

data SortField = ByRating | ByYear
  deriving (Show, Eq)

data SortOrder = Asc | Desc
  deriving (Show, Eq)

-- Через Set значения одновременно дедуплицируются и упорядочиваются,
-- так что нумерация в меню не скачет от запуска к запуску.
distinct :: (Serial -> [String]) -> [Serial] -> [String]
distinct field = Set.toAscList . Set.fromList . concatMap field

genres :: [Serial] -> [String]
genres = distinct genre

actorNames :: [Serial] -> [String]
actorNames = distinct actors

directors :: [Serial] -> [String]
directors = distinct (\s -> [director s])

filterByGenre :: String -> [Serial] -> [Serial]
filterByGenre g = filter (elem g . genre)

filterByActor :: String -> [Serial] -> [Serial]
filterByActor a = filter (elem a . actors)

filterByDirector :: String -> [Serial] -> [Serial]
filterByDirector d = filter ((== d) . director)

sortSerials :: SortField -> SortOrder -> [Serial] -> [Serial]
sortSerials ByRating Asc  = sortOn rating
sortSerials ByRating Desc = sortOn (Down . rating)
sortSerials ByYear   Asc  = sortOn year
sortSerials ByYear   Desc = sortOn (Down . year)

-- Ищем по названию, режиссёру и году сразу: пользователь редко помнит,
-- какое именно поле он вводит.
search :: String -> [Serial] -> [Serial]
search query = filter matches
  where
    needle = lower query
    matches s = any ((needle `isInfixOf`) . lower) [title s, director s, show (year s)]
    lower = map toLower
