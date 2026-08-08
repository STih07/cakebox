{-# LANGUAGE OverloadedStrings #-}

module PageFactory.App.Server
  ( generateStatic
  , serve
  ) where

-- WAI application, response selection, static generation, and Warp startup.

import Control.Monad (forM_)
import Data.Char (isAlphaNum, toUpper)
import Data.List (find)
import Network.HTTP.Types (status200, status204, status404)
import Network.Wai (Application, Request, Response)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import PageFactory.AgUi (agUiRunResponse)
import PageFactory.App.Routes (Route (..), parseRoute)
import PageFactory.Ai (ChatState, TraceStore, initTraceStore, newChatState)
import PageFactory.Chat.ActionServer (extensionActionResponse)
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
import PageFactory.ModelBuilder.Store (ModelStore, initModelStore, listModelConfigs)
import PageFactory.ModelBuilder.View (modelBuilderView)
import PageFactory.Sandbox.Store (SandboxStore, getSandboxDoc, initSandboxStore, listSandboxDocs)
import PageFactory.Sandbox.View (sandboxCatalogView, sandboxDocumentView)
import PageFactory.Stories.View (storyIndexView, storyView)
import PageFactory.Trading.DataSource (loadTickerQuotes)
import PageFactory.Trading.State (TradingState, newTradingState, readTradingSymbols)
import PageFactory.Trading.View (aiTradingView, tickerDetailView)
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

app :: FilePath -> TraceStore -> ChatState -> TradingState -> SandboxStore -> ModelStore -> Application
app inputPath traceStore chatState tradingState sandboxStore modelStore req respond = do
  clients <- loadClients inputPath
  response <- handleRequest traceStore chatState tradingState sandboxStore modelStore clients req
  respond response

handleRequest :: TraceStore -> ChatState -> TradingState -> SandboxStore -> ModelStore -> [Client] -> Request -> IO Response
handleRequest traceStore chatState tradingState sandboxStore modelStore clients req =
  case parseRoute req of
    HealthRoute ->
      pure (plainResponse status200 "ok\n")
    FaviconRoute ->
      pure (plainResponse status204 "")
    AgUiRunRoute ->
      agUiRunResponse traceStore chatState tradingState sandboxStore modelStore clients req
    ExtensionActionRoute ->
      extensionActionResponse tradingState sandboxStore modelStore req
    HomeRoute ->
      pure (htmlResponse status200 (renderFor mode "Фабрика клиентских страниц" (indexView clients)))
    AiTradingRoute -> do
      symbols <- readTradingSymbols tradingState
      quotesResult <- loadTickerQuotes symbols
      pure (htmlResponse status200 (renderFor mode "AI Trading" (aiTradingView quotesResult)))
    AiTradingTickerRoute rawSymbol ->
      case normalizeTickerSymbol rawSymbol of
        Nothing ->
          pure (htmlResponse status404 (renderFor mode "Ticker not found" (notFoundView "Ticker not found")))
        Just symbol -> do
          quoteResult <- loadTickerQuotes [symbol]
          pure (htmlResponse status200 (renderFor mode ("AI Trading " <> symbol) (tickerDetailView symbol quoteResult)))
    ModelsRoute -> do
      models <- listModelConfigs modelStore
      pure (htmlResponse status200 (renderFor mode "Model Builder" (modelBuilderView models)))
    SandboxRoute -> do
      docs <- listSandboxDocs sandboxStore
      pure (htmlResponse status200 (renderFor mode "Sandbox" (sandboxCatalogView docs)))
    SandboxDocumentRoute slug -> do
      maybeDoc <- getSandboxDoc sandboxStore slug
      case maybeDoc of
        Nothing ->
          pure (htmlResponse status404 (renderFor mode "Document not found" (notFoundView "Document not found")))
        Just doc ->
          pure (htmlResponse status200 (renderFor mode ("Sandbox " <> slug) (sandboxDocumentView doc)))
    StoriesRoute ->
      pure (htmlResponse status200 (renderFor mode "Cakebook" storyIndexView))
    StoryRoute slug ->
      pure (htmlResponse status200 (renderFor mode ("Cakebook " <> slug) (storyView slug)))
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

normalizeTickerSymbol :: String -> Maybe String
normalizeTickerSymbol rawSymbol =
  let symbol = map toUpper (filter (/= ' ') rawSymbol)
   in if not (null symbol) && length symbol <= 8 && all isAlphaNum symbol
        then Just symbol
        else Nothing

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
  let storePath = "var/page-factory.sqlite3"
  traceStore <- initTraceStore storePath
  sandboxStore <- initSandboxStore storePath
  modelStore <- initModelStore storePath
  putStrLn ("Page factory listening on http://" <> host <> ":" <> show port)
  runSettings (setHost "127.0.0.1" (setPort port defaultSettings)) (app inputPath traceStore chatState tradingState sandboxStore modelStore)
