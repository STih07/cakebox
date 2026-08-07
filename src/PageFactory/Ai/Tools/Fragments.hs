{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Ai.Tools.Fragments
  ( ToolExecution (..)
  , executeFragmentTool
  ) where

-- Local MCP-like fragment and UI action tools. Replace this boundary with real MCP transport later.

import Data.Aeson (FromJSON (..), Value, eitherDecode, object, withObject, (.:), (.:?), (.=))
import Data.List (find)
import qualified Data.ByteString.Lazy.Char8 as LBS
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..), ToolResult (..))
import PageFactory.Clients
  ( Client (..)
  , clientPanel
  , clientTabFromSlug
  , clientTabPath
  , clientTabTitle
  )
import PageFactory.Engine.Html (renderHtml)
import PageFactory.Engine (raw, tag, text)
import PageFactory.Trading (tradingPanel)
import PageFactory.Trading.DataSource (loadTickerQuotes)
import PageFactory.Trading.State (TradingState, addTradingTicker, readTradingSymbols)

data ToolExecution = ToolExecution
  { toolExecutionResult :: ToolResult
  , toolExecutionEvents :: [(String, Value)]
  }
  deriving (Eq, Show)

data FragmentArgs = FragmentArgs
  { fragmentClientId :: Int
  , fragmentTab :: String
  }
  deriving (Eq, Show)

data ThemeArgs = ThemeArgs
  { themeColor :: String
  , themeNote :: Maybe String
  }
  deriving (Eq, Show)

data OrderArgs = OrderArgs
  { orderId :: Maybe String
  , customer :: Maybe String
  , country :: Maybe String
  , total :: Maybe Double
  , shippingMethod :: Maybe String
  , status :: Maybe String
  , note :: Maybe String
  }
  deriving (Eq, Show)

data TradingTickerArgs = TradingTickerArgs
  { tradingSymbol :: String
  }
  deriving (Eq, Show)

parseFragmentArgs :: String -> Either String FragmentArgs
parseFragmentArgs =
  eitherDecode . LBS.pack

parseThemeArgs :: String -> Either String ThemeArgs
parseThemeArgs =
  eitherDecode . LBS.pack

parseOrderArgs :: String -> Either String OrderArgs
parseOrderArgs =
  eitherDecode . LBS.pack

parseTradingTickerArgs :: String -> Either String TradingTickerArgs
parseTradingTickerArgs =
  eitherDecode . LBS.pack

instance FromJSON FragmentArgs where
  parseJSON =
    withObject "FragmentArgs" $ \value ->
      FragmentArgs
        <$> value .: "clientId"
        <*> value .: "tab"

instance FromJSON ThemeArgs where
  parseJSON =
    withObject "ThemeArgs" $ \value ->
      ThemeArgs
        <$> value .: "themeColor"
        <*> value .:? "note"

instance FromJSON OrderArgs where
  parseJSON =
    withObject "OrderArgs" $ \value ->
      OrderArgs
        <$> value .:? "orderId"
        <*> value .:? "customer"
        <*> value .:? "country"
        <*> value .:? "total"
        <*> value .:? "shippingMethod"
        <*> value .:? "status"
        <*> value .:? "note"

instance FromJSON TradingTickerArgs where
  parseJSON =
    withObject "TradingTickerArgs" $ \value ->
      TradingTickerArgs <$> value .: "symbol"

executeFragmentTool :: [Client] -> TradingState -> ToolCall -> IO ToolExecution
executeFragmentTool clients tradingState call
  | toolCallName call == "open_client_page" =
      case parseFragmentArgs (toolCallArguments call) of
        Left err ->
          pure (failed ("Bad open_client_page arguments: " <> err))
        Right args ->
          case (find ((== fragmentClientId args) . clientId) clients, clientTabFromSlug (fragmentTab args)) of
            (Just client, Just tabName) ->
              pure (opened client tabName)
            _ ->
              pure (failed "Client or tab not found")
  | toolCallName call == "render_client_fragment" =
      case parseFragmentArgs (toolCallArguments call) of
        Left err ->
          pure (failed ("Bad render_client_fragment arguments: " <> err))
        Right args ->
          case (find ((== fragmentClientId args) . clientId) clients, clientTabFromSlug (fragmentTab args)) of
            (Just client, Just tabName) ->
              pure (rendered client tabName)
            _ ->
              pure (failed "Client or tab not found")
  | toolCallName call == "set_theme_color" =
      case parseThemeArgs (toolCallArguments call) of
        Left err -> pure (failed ("Bad set_theme_color arguments: " <> err))
        Right args -> pure (themeUpdated args)
  | toolCallName call == "update_order_draft" =
      case parseOrderArgs (toolCallArguments call) of
        Left err -> pure (failed ("Bad update_order_draft arguments: " <> err))
        Right args -> pure (orderUpdated args)
  | toolCallName call == "open_trading_tickers" =
      pure openedTradingTickers
  | toolCallName call == "refresh_trading_quotes" =
      refreshTradingPanel "OK: Refreshed AI Trading tickers"
  | toolCallName call == "add_trading_ticker" =
      case parseTradingTickerArgs (toolCallArguments call) of
        Left err -> pure (failed ("Bad add_trading_ticker arguments: " <> err))
        Right args -> do
          updateResult <- addTradingTicker tradingState (tradingSymbol args)
          case updateResult of
            Left message -> pure (failed message)
            Right _ -> refreshTradingPanel ("OK: Added " <> tradingSymbol args <> " to AI Trading tickers")
  | otherwise =
      pure (failed ("Unknown tool: " <> toolCallName call))
  where
    failed message =
      ToolExecution
        { toolExecutionResult =
            ToolResult
              { toolResultCallId = toolCallId call
              , toolResultName = toolCallName call
              , toolResultContent = "ERROR: " <> message
              }
        , toolExecutionEvents = []
        }

    rendered client tabName =
      let html =
            renderHtml
              ( tag
                  "div"
                  [("class", "agent-fragment-preview"), ("data-fragment-slot", "agent-tool-fragment")]
                  ( tag "p" [] (text ("AI tool rendered: " <> label))
                      <> raw (renderHtml (clientPanel client tabName))
                  )
              )
          label = "client " <> show (clientId client) <> " / " <> clientTabTitle tabName
       in ToolExecution
            { toolExecutionResult =
                ToolResult
                  { toolResultCallId = toolCallId call
              , toolResultName = toolCallName call
              , toolResultContent = "OK: Rendered Layered HTML fragment: " <> label
              }
            , toolExecutionEvents =
                [
                  ( "fragment.rendered"
                  , object
                      [ "target" .= ("agent-tool-fragment" :: String)
                      , "label" .= label
                      , "html" .= html
                      ]
                  )
                ]
            }

    openedTradingTickers =
      let finalNote = "OK: Opened AI Trading tickers"
       in ToolExecution
            { toolExecutionResult =
                ToolResult
                  { toolResultCallId = toolCallId call
                  , toolResultName = toolCallName call
                  , toolResultContent = finalNote
                  }
            , toolExecutionEvents =
                [ ( "ui.action"
                  , object
                      [ "action" .= ("navigate" :: String)
                      , "url" .= ("/ai-trading/tickers" :: String)
                      , "label" .= ("AI Trading / Тикеры" :: String)
                      , "note" .= finalNote
                      ]
                  )
                , ( "state.updated"
                  , object
                      [ "currentModule" .= ("AI Trading" :: String)
                      , "currentTab" .= ("Тикеры" :: String)
                      , "note" .= finalNote
                      ]
                  )
                ]
            }

    refreshTradingPanel finalNote = do
      symbols <- readTradingSymbols tradingState
      quotesResult <- loadTickerQuotes symbols
      let html = renderHtml (tradingPanel quotesResult)
          content =
            case quotesResult of
              Left message -> "ERROR: " <> message
              Right _ -> finalNote
      pure
        ToolExecution
          { toolExecutionResult =
              ToolResult
                { toolResultCallId = toolCallId call
                , toolResultName = toolCallName call
                , toolResultContent = content
                }
          , toolExecutionEvents =
              [ ( "fragment.rendered"
                , object
                    [ "target" .= ("trading-panel" :: String)
                    , "label" .= ("AI Trading / Тикеры" :: String)
                    , "html" .= html
                    ]
                )
              , ( "state.updated"
                , object
                    [ "tradingSymbols" .= symbols
                    , "note" .= content
                    ]
                )
              ]
          }

    opened client tabName =
      let url = clientTabPath client tabName
          label = "client " <> show (clientId client) <> " / " <> clientTabTitle tabName
          finalNote = "OK: Opened client page: " <> label
       in ToolExecution
            { toolExecutionResult =
                ToolResult
                  { toolResultCallId = toolCallId call
                  , toolResultName = toolCallName call
                  , toolResultContent = finalNote
                  }
            , toolExecutionEvents =
                [ ( "ui.action"
                  , object
                      [ "action" .= ("navigate" :: String)
                      , "url" .= url
                      , "label" .= label
                      , "note" .= finalNote
                      ]
                  )
                , ( "state.updated"
                  , object
                      [ "currentClientId" .= clientId client
                      , "currentClientTab" .= clientTabTitle tabName
                      , "note" .= finalNote
                      ]
                  )
                ]
            }

    themeUpdated args =
      let requestedColor = themeColor args
          fallbackNote = "OK: Theme changed to " <> requestedColor
          finalNote = maybe fallbackNote (\noteText -> fallbackNote <> ". " <> noteText) (themeNote args)
       in ToolExecution
            { toolExecutionResult =
                ToolResult
                  { toolResultCallId = toolCallId call
                  , toolResultName = toolCallName call
                  , toolResultContent = finalNote
                  }
            , toolExecutionEvents =
                [ ( "ui.action"
                  , object
                      [ "action" .= ("setThemeColor" :: String)
                      , "themeColor" .= requestedColor
                      , "requestedThemeColor" .= requestedColor
                      , "note" .= finalNote
                      ]
                  )
                , ( "state.updated"
                  , object
                      [ "preferredTheme" .= requestedColor
                      , "requestedThemeColor" .= requestedColor
                      , "note" .= finalNote
                      ]
                  )
                ]
            }

    orderUpdated args =
      let finalNote = maybe "OK: Order draft updated" ("OK: " <>) (note args)
       in ToolExecution
            { toolExecutionResult =
                ToolResult
                  { toolResultCallId = toolCallId call
                  , toolResultName = toolCallName call
                  , toolResultContent = finalNote
                  }
            , toolExecutionEvents =
                [ ( "ui.action"
                  , object
                      [ "action" .= ("updateOrderDraft" :: String)
                      , "orderId" .= orderId args
                      , "customer" .= customer args
                      , "country" .= country args
                      , "total" .= total args
                      , "shippingMethod" .= shippingMethod args
                      , "status" .= status args
                      , "note" .= finalNote
                      ]
                  )
                , ( "state.updated"
                  , object
                      [ "lastOrderId" .= orderId args
                      , "note" .= finalNote
                      ]
                  )
                ]
            }
