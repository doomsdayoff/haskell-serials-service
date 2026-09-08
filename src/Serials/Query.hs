{-# LANGUAGE OverloadedStrings #-}

module Serials.Query
  ( SortField (..)
  , SortOrder (..)
  , parseSortField
  , parseSortOrder
  , genres
  , actorNames
  , directors
  , filterSerials
  , sortSerials
  , search
  , findByTitle
  ) where

import Data.List (find, sortOn)
import Data.Ord (Down (..))
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T

import Serials.Types

data SortField = ByRating | ByYear
  deriving (Show, Eq)

data SortOrder = Asc | Desc
  deriving (Show, Eq)

parseSortField :: Text -> Maybe SortField
parseSortField raw = case T.toLower raw of
  "rating" -> Just ByRating
  "year"   -> Just ByYear
  _        -> Nothing

parseSortOrder :: Text -> Maybe SortOrder
parseSortOrder raw = case T.toLower raw of
  "asc"  -> Just Asc
  "desc" -> Just Desc
  _      -> Nothing

-- Через Set значения одновременно дедуплицируются и упорядочиваются,
-- так что справочник не меняет порядок от запуска к запуску.
distinct :: (Serial -> [Text]) -> [Serial] -> [Text]
distinct field = Set.toAscList . Set.fromList . concatMap field

genres :: [Serial] -> [Text]
genres = distinct genre

actorNames :: [Serial] -> [Text]
actorNames = distinct actors

directors :: [Serial] -> [Text]
directors = distinct (\s -> [director s])

-- Незаданный критерий не отсекает ничего, поэтому параметры складываются:
-- ?genre=Drama&director=Vince+Gilligan сужает выборку по обоим полям сразу.
filterSerials :: Maybe Text -> Maybe Text -> Maybe Text -> [Serial] -> [Serial]
filterSerials wantGenre wantActor wantDirector = filter keep
  where
    keep s = matches wantGenre (genre s)
          && matches wantActor (actors s)
          && matches wantDirector [director s]
    matches want values = maybe True (\w -> any (sameAs w) values) want

sortSerials :: SortField -> SortOrder -> [Serial] -> [Serial]
sortSerials ByRating Asc  = sortOn rating
sortSerials ByRating Desc = sortOn (Down . rating)
sortSerials ByYear   Asc  = sortOn year
sortSerials ByYear   Desc = sortOn (Down . year)

-- Ищем по названию, режиссёру и году сразу: пользователь редко помнит,
-- какое именно поле он вводит.
search :: Text -> [Serial] -> [Serial]
search query = filter matches
  where
    needle = T.toCaseFold (T.strip query)
    matches s = any (T.isInfixOf needle . T.toCaseFold)
                    [title s, director s, T.pack (show (year s))]

findByTitle :: Text -> [Serial] -> Maybe Serial
findByTitle wanted = find (sameAs wanted . title)

sameAs :: Text -> Text -> Bool
sameAs a b = T.toCaseFold (T.strip a) == T.toCaseFold b
