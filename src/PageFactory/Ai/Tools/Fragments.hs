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
import PageFactory.Trading.Actions (executeTradingTool)
import PageFactory.Trading.State (TradingState)

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

parseFragmentArgs :: String -> Either String FragmentArgs
parseFragmentArgs =
  eitherDecode . LBS.pack

parseThemeArgs :: String -> Either String ThemeArgs
parseThemeArgs =
  eitherDecode . LBS.pack

parseOrderArgs :: String -> Either String OrderArgs
parseOrderArgs =
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

executeFragmentTool :: [Client] -> TradingState -> ToolCall -> IO ToolExecution
executeFragmentTool clients tradingState call
  | Just action <- executeTradingTool tradingState call = do
      (content, events) <- action
      pure
        ToolExecution
          { toolExecutionResult =
              ToolResult
                { toolResultCallId = toolCallId call
                , toolResultName = toolCallName call
                , toolResultContent = content
                }
          , toolExecutionEvents = events
          }
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
