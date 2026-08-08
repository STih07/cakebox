{-# LANGUAGE OverloadedStrings #-}

module PageFactory.App.Routes
  ( Route (..)
  , parseRoute
  ) where

-- HTTP route parsing from WAI path segments into domain routes.

import Data.Char (isSpace)
import Data.List (isPrefixOf)
import qualified Data.Text as T
import Network.Wai (Request, pathInfo)
import PageFactory.Clients (ClientTab (..), clientTabFromSlug)

data Route
  = HomeRoute
  | AiTradingRoute
  | AiTradingTickerRoute String
  | SandboxRoute
  | SandboxDocumentRoute String
  | ClientRoute Int ClientTab
  | AgUiRunRoute
  | ExtensionActionRoute
  | FaviconRoute
  | HealthRoute
  | MissingRoute
  deriving (Eq, Show)

parseRoute :: Request -> Route
parseRoute req =
  case pathInfo req of
    [] -> HomeRoute
    ["health"] -> HealthRoute
    ["favicon.ico"] -> FaviconRoute
    ["ag-ui", "runs"] -> AgUiRunRoute
    ["extensions", "actions"] -> ExtensionActionRoute
    ["ai-trading"] -> AiTradingRoute
    ["ai-trading", "tickers"] -> AiTradingRoute
    ["ai-trading", "tickers", rawSymbol] -> AiTradingTickerRoute (T.unpack rawSymbol)
    ["sandbox"] -> SandboxRoute
    ["sandbox", "docs", rawSlug] -> SandboxDocumentRoute (T.unpack rawSlug)
    ["clients"] -> HomeRoute
    ["clients", rawId] ->
      maybe MissingRoute (`ClientRoute` OverviewTab) (readMaybeInt (T.unpack rawId))
    ["clients", rawId, rawTab] ->
      case (readMaybeInt (T.unpack rawId), clientTabFromSlug (T.unpack rawTab)) of
        (Just clientIdValue, Just tabName) -> ClientRoute clientIdValue tabName
        _ -> MissingRoute
    [fileName]
      | "client-" `isPrefixOf` T.unpack fileName ->
          maybe MissingRoute (`ClientRoute` OverviewTab) (legacyClientId (T.unpack fileName))
    _ -> MissingRoute

legacyClientId :: String -> Maybe Int
legacyClientId fileName =
  case splitOn '-' fileName of
    (_ : rawId : _) -> readMaybeInt rawId
    _ -> Nothing

readMaybeInt :: String -> Maybe Int
readMaybeInt value =
  case reads value of
    [(number, rest)] | all isSpace rest -> Just number
    _ -> Nothing

splitOn :: Char -> String -> [String]
splitOn delimiter = foldr step [""]
  where
    step c acc@(x : xs)
      | c == delimiter = "" : acc
      | otherwise = (c : x) : xs
    step _ [] = []
