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
  , clientTabTitle
  )
import PageFactory.Engine.Html (renderHtml)
import PageFactory.Engine (raw, tag, text)

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

executeFragmentTool :: [Client] -> ToolCall -> ToolExecution
executeFragmentTool clients call
  | toolCallName call == "render_client_fragment" =
      case parseFragmentArgs (toolCallArguments call) of
        Left err ->
          failed ("Bad render_client_fragment arguments: " <> err)
        Right args ->
          case (find ((== fragmentClientId args) . clientId) clients, clientTabFromSlug (fragmentTab args)) of
            (Just client, Just tabName) ->
              rendered client tabName
            _ ->
              failed "Client or tab not found"
  | toolCallName call == "set_theme_color" =
      case parseThemeArgs (toolCallArguments call) of
        Left err -> failed ("Bad set_theme_color arguments: " <> err)
        Right args -> themeUpdated args
  | toolCallName call == "update_order_draft" =
      case parseOrderArgs (toolCallArguments call) of
        Left err -> failed ("Bad update_order_draft arguments: " <> err)
        Right args -> orderUpdated args
  | otherwise =
      failed ("Unknown tool: " <> toolCallName call)
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
