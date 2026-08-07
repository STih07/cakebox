{-# LANGUAGE OverloadedStrings #-}

module PageFactory.App.Server
  ( generateStatic
  , serve
  ) where

-- WAI application, response selection, static generation, and Warp startup.

import Control.Monad (forM_)
import Data.List (find)
import Network.HTTP.Types (status200, status204, status404)
import Network.Wai (Application, Request, Response)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import PageFactory.AgUi (agUiRunResponse)
import PageFactory.App.Routes (Route (..), parseRoute)
import PageFactory.Ai (ChatState, TraceStore, initTraceStore, newChatState)
import PageFactory.Clients
  ( Client (..)
  , ClientTab (..)
  , clientFileName
  , clientPanel
  , clientView
  , indexView
  , loadClients
  )
import PageFactory.Engine
  ( Html
  , RenderMode (..)
  , document
  , htmlResponse
  , plainResponse
  , renderFor
  , renderMode
  , renderTarget
  , tag
  , text
  , writePage
  )
import PageFactory.Trading (aiTradingView)
import PageFactory.Trading.DataSource (loadTickerQuotes)
import PageFactory.Trading.State (TradingState, newTradingState, readTradingSymbols)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

generateStatic :: IO ()
generateStatic = do
  let inputPath = "data/clients.csv"
  let outputDir = "public"

  clients <- loadClients inputPath
  createDirectoryIfMissing True outputDir

  writePage (outputDir </> "index.html") (document "Фабрика клиентских страниц" (indexView clients))

  forM_ clients $ \client ->
    writePage (outputDir </> clientFileName client) (document ("Клиент " <> clientName client) (clientView client OverviewTab))

  putStrLn ("Generated " <> show (length clients + 1) <> " pages into " <> outputDir)

app :: FilePath -> TraceStore -> ChatState -> TradingState -> Application
app inputPath traceStore chatState tradingState req respond = do
  clients <- loadClients inputPath
  response <- handleRequest traceStore chatState tradingState clients req
  respond response

handleRequest :: TraceStore -> ChatState -> TradingState -> [Client] -> Request -> IO Response
handleRequest traceStore chatState tradingState clients req =
  case parseRoute req of
    HealthRoute ->
      pure (plainResponse status200 "ok\n")
    FaviconRoute ->
      pure (plainResponse status204 "")
    AgUiRunRoute ->
      agUiRunResponse traceStore chatState tradingState clients req
    HomeRoute ->
      pure (htmlResponse status200 (renderFor mode "Фабрика клиентских страниц" (indexView clients)))
    AiTradingRoute -> do
      symbols <- readTradingSymbols tradingState
      quotesResult <- loadTickerQuotes symbols
      pure (htmlResponse status200 (renderFor mode "AI Trading" (aiTradingView quotesResult)))
    ClientRoute wantedId activeTab ->
      case find ((== wantedId) . clientId) clients of
        Just client ->
          pure (htmlResponse status200 (renderClientResponse mode target client activeTab))
        Nothing ->
          pure (htmlResponse status404 (renderFor mode "Клиент не найден" (notFoundView "Клиент не найден")))
    MissingRoute ->
      pure (htmlResponse status404 (renderFor mode "Страница не найдена" (notFoundView "Страница не найдена")))
  where
    mode = renderMode req
    target = renderTarget req

renderClientResponse :: RenderMode -> Maybe String -> Client -> ClientTab -> Html
renderClientResponse FragmentOnly (Just "client-panel") client activeTab = clientPanel client activeTab
renderClientResponse mode _ client activeTab =
  renderFor mode ("Клиент " <> clientName client) (clientView client activeTab)

notFoundView :: String -> Html
notFoundView message =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "not-found")]
    ( tag "section" [("class", "profile")]
        ( tag "p" [("class", "eyebrow")] (text "404")
            <> tag "h1" [] (text message)
            <> tag "p" [] (text "Такого маршрута в фабрике пока нет.")
        )
    )

serve :: IO ()
serve = do
  let port = 8098
  let host = "127.0.0.1"
  let inputPath = "data/clients.csv"
  chatState <- newChatState
  tradingState <- newTradingState
  traceStore <- initTraceStore "var/page-factory.sqlite3"
  putStrLn ("Page factory listening on http://" <> host <> ":" <> show port)
  runSettings (setHost "127.0.0.1" (setPort port defaultSettings)) (app inputPath traceStore chatState tradingState)
