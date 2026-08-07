{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Ai.Provider.OpenAICompat
  ( ToolCall (..)
  , ToolResult (..)
  , chooseToolCalls
  , streamChatCompletion
  ) where

-- OpenAI-compatible Chat Completions client with tool planning and token streaming.

import Control.Exception (SomeException, try)
import Control.Monad (foldM)
import Data.Aeson (FromJSON (..), Value (..), eitherDecode, encode, object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import Data.List (isPrefixOf, stripPrefix)
import Data.Maybe (catMaybes, mapMaybe)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import qualified Data.Text.Encoding.Error as Text
import Network.HTTP.Client
  ( Request (..)
  , RequestBody (..)
  , Response (..)
  , BodyReader
  , brRead
  , httpLbs
  , method
  , parseRequest
  , requestBody
  , requestHeaders
  , responseClose
  , responseOpen
  )
import Network.HTTP.Client.TLS (newTlsManager)
import Network.HTTP.Types.Header (HeaderName, RequestHeaders)
import Network.HTTP.Types.Status (statusCode)
import PageFactory.Ai.ChatState (ChatMessage (..))
import PageFactory.Ai.Provider.Config (AiProviderConfig (..))

data ToolCall = ToolCall
  { toolCallId :: String
  , toolCallName :: String
  , toolCallArguments :: String
  , toolCallJson :: Value
  }
  deriving (Eq, Show)

data ToolResult = ToolResult
  { toolResultCallId :: String
  , toolResultName :: String
  , toolResultContent :: String
  }
  deriving (Eq, Show)

data ChatCompletion = ChatCompletion [ChatChoice]

instance FromJSON ChatCompletion where
  parseJSON =
    withObject "ChatCompletion" $ \value ->
      ChatCompletion <$> value .: "choices"

data ChatChoice = ChatChoice ChatMessageResponse

instance FromJSON ChatChoice where
  parseJSON =
    withObject "ChatChoice" $ \value ->
      ChatChoice <$> value .: "message"

data ChatMessageResponse = ChatMessageResponse (Maybe String) [ToolCall]

instance FromJSON ChatMessageResponse where
  parseJSON =
    withObject "ChatMessageResponse" $ \value ->
      ChatMessageResponse
        <$> value .:? "content"
        <*> value .:? "tool_calls" .!= []

instance FromJSON ToolCall where
  parseJSON =
    withObject "ToolCall" $ \value -> do
      ident <- value .: "id"
      functionValue <- value .: "function"
      withObject
        "ToolCallFunction"
        ( \functionObject ->
            ToolCall ident
              <$> functionObject .: "name"
              <*> functionObject .: "arguments"
              <*> pure (Object value)
        )
        functionValue

data ChatChunk = ChatChunk [ChunkChoice]

instance FromJSON ChatChunk where
  parseJSON =
    withObject "ChatChunk" $ \value ->
      ChatChunk <$> value .:? "choices" .!= []

data ChunkChoice = ChunkChoice (Maybe String)

instance FromJSON ChunkChoice where
  parseJSON =
    withObject "ChunkChoice" $ \value -> do
      deltaValue <- value .: "delta"
      withObject
        "ChunkDelta"
        (\deltaObject -> ChunkChoice <$> deltaObject .:? "content")
        deltaValue

chooseToolCalls :: AiProviderConfig -> [ChatMessage] -> IO (Either String [ToolCall])
chooseToolCalls config messages =
  case providerApiKey config of
    Nothing ->
      pure (Left "AI key is not configured")
    Just apiKey -> do
      manager <- newTlsManager
      request <- buildJsonRequest config apiKey False (toolPlanningPayload config messages)
      result <- try (httpLbs request manager) :: IO (Either SomeException (Response LBS.ByteString))
      pure $
        case result of
          Left err -> Left (show err)
          Right response
            | statusCode (responseStatus response) >= 300 ->
                Left ("provider returned HTTP " <> show (statusCode (responseStatus response)))
            | otherwise ->
                case eitherDecode (responseBody response) of
                  Left err -> Left err
                  Right (ChatCompletion choices) -> Right (concatMap choiceTools choices)
  where
    choiceTools (ChatChoice (ChatMessageResponse _ calls)) = calls

streamChatCompletion :: AiProviderConfig -> [ChatMessage] -> [ToolCall] -> [ToolResult] -> (String -> IO ()) -> IO (Either String String)
streamChatCompletion config messages toolCalls toolResults onDelta =
  case providerApiKey config of
    Nothing ->
      pure (Left "AI key is not configured")
    Just apiKey -> do
      manager <- newTlsManager
      request <- buildStreamingRequest config apiKey (streamingPayload config messages toolCalls toolResults)
      result <- try (responseOpen request manager) :: IO (Either SomeException (Response BodyReader))
      case result of
        Left err ->
          pure (Left (show err))
        Right response
          | statusCode (responseStatus response) >= 300 -> do
              body <- readStreamingBody response
              responseClose response
              pure (Left ("provider returned HTTP " <> show (statusCode (responseStatus response)) <> ": " <> body))
          | otherwise -> do
              streamResult <- consumeSse response "" "" onDelta
              responseClose response
              pure streamResult

toolPlanningPayload :: AiProviderConfig -> [ChatMessage] -> Value
toolPlanningPayload config messages =
  object
    [ "model" .= providerModel config
    , "stream" .= False
    , "temperature" .= (0 :: Int)
    , "messages" .= (systemMessage : map chatMessageJson messages)
    , "tools" .= runtimeTools
    , "tool_choice" .= ("auto" :: String)
    ]

streamingPayload :: AiProviderConfig -> [ChatMessage] -> [ToolCall] -> [ToolResult] -> Value
streamingPayload config messages toolCalls toolResults =
  object
    [ "model" .= providerModel config
    , "stream" .= True
    , "temperature" .= (0.4 :: Double)
    , "messages" .= (systemMessage : map chatMessageJson messages <> toolConversation)
    ]
  where
    toolConversation =
      if null toolCalls
        then []
        else [assistantToolMessage toolCalls] <> map toolResultMessage toolResults

systemMessage :: Value
systemMessage =
  object
    [ "role" .= ("system" :: String)
    , "content" .= systemPrompt
    ]

systemPrompt :: String
systemPrompt =
  "Ты AI внутри Haskell Layered HTML фабрики. Отвечай кратко и по делу на русском. "
    <> "У тебя есть декларативные runtime tools как в CopilotKit: open_client_page, render_client_fragment, set_theme_color, update_order_draft. "
    <> "Для AI Trading используй open_trading_tickers, add_trading_ticker, refresh_trading_quotes. "
    <> "Вызывай tool только когда пользователь просит изменить интерфейс, форму, state или открыть сегмент. "
    <> "Если пользователь просит открыть страницу клиента, используй open_client_page, а не render_client_fragment. "
    <> "render_client_fragment используй только когда пользователь просит показать или вставить фрагмент в чате/preview. "
    <> "Для set_theme_color всегда передавай валидный CSS цвет: rgb(...), hsl(...) или hex. "
    <> "Если пользователь называет цвет словами, сам преобразуй его в подходящий rgb/hex до tool-вызова; не передавай русские названия цветов. "
    <> "Если tool result начинается с OK:, tool сработал успешно; не называй это ошибкой. "
    <> "Если tool result начинается с ERROR:, кратко объясни точную ошибку. "
    <> "После tool-вызова объясни только tool results текущего run; не приписывай к ответу старые действия из истории."

chatMessageJson :: ChatMessage -> Value
chatMessageJson message =
  object
    [ "role" .= chatRole message
    , "content" .= chatContent message
    ]

assistantToolMessage :: [ToolCall] -> Value
assistantToolMessage calls =
  object
    [ "role" .= ("assistant" :: String)
    , "content" .= Null
    , "tool_calls" .= map toolCallJson calls
    ]

toolResultMessage :: ToolResult -> Value
toolResultMessage result =
  object
    [ "role" .= ("tool" :: String)
    , "tool_call_id" .= toolResultCallId result
    , "name" .= toolResultName result
    , "content" .= toolResultContent result
    ]

runtimeTools :: [Value]
runtimeTools =
  [ openClientPageTool
  , renderClientFragmentTool
  , setThemeColorTool
  , updateOrderDraftTool
  , openTradingTickersTool
  , addTradingTickerTool
  , refreshTradingQuotesTool
  ]

openClientPageTool :: Value
openClientPageTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("open_client_page" :: String)
          , "description" .= ("Open a client page in the main Haskell page surface using fragment navigation." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "clientId" .= object ["type" .= ("integer" :: String)]
                      , "tab" .= object ["type" .= ("string" :: String), "enum" .= (["overview", "invoices", "activity", "ai"] :: [String])]
                      ]
                , "required" .= (["clientId", "tab"] :: [String])
                , "additionalProperties" .= False
                ]
          ]
    ]

renderClientFragmentTool :: Value
renderClientFragmentTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("render_client_fragment" :: String)
          , "description" .= ("Render a typed Layered HTML fragment for a client tab." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "clientId" .= object ["type" .= ("integer" :: String)]
                      , "tab" .= object ["type" .= ("string" :: String), "enum" .= (["overview", "invoices", "activity"] :: [String])]
                      ]
                , "required" .= (["clientId", "tab"] :: [String])
                , "additionalProperties" .= False
                ]
          ]
    ]

setThemeColorTool :: Value
setThemeColorTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("set_theme_color" :: String)
          , "description" .= ("Declaratively change the Haskell page accent color in the browser." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "themeColor" .= object ["type" .= ("string" :: String), "description" .= ("Valid CSS color only, such as rgb(245, 245, 220), hsl(60 56% 91%), or #f5f5dc. Convert natural-language colors yourself before calling this tool." :: String)]
                      , "note" .= object ["type" .= ("string" :: String)]
                      ]
                , "required" .= (["themeColor"] :: [String])
                , "additionalProperties" .= False
                ]
          ]
    ]

updateOrderDraftTool :: Value
updateOrderDraftTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("update_order_draft" :: String)
          , "description" .= ("Declaratively update the visible Haskell-rendered order form." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "orderId" .= object ["type" .= ("string" :: String)]
                      , "customer" .= object ["type" .= ("string" :: String)]
                      , "country" .= object ["type" .= ("string" :: String)]
                      , "total" .= object ["type" .= ("number" :: String)]
                      , "shippingMethod" .= object ["type" .= ("string" :: String)]
                      , "status" .= object ["type" .= ("string" :: String)]
                      , "note" .= object ["type" .= ("string" :: String)]
                      ]
                , "additionalProperties" .= False
                ]
          ]
    ]

openTradingTickersTool :: Value
openTradingTickersTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("open_trading_tickers" :: String)
          , "description" .= ("Open the AI Trading tickers module in the main Haskell page surface." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties" .= object []
                , "additionalProperties" .= False
                ]
          ]
    ]

addTradingTickerTool :: Value
addTradingTickerTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("add_trading_ticker" :: String)
          , "description" .= ("Add a ticker symbol to the AI Trading watchlist and re-render the trading panel." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "symbol" .= object ["type" .= ("string" :: String), "description" .= ("Ticker symbol, for example PLTR, AAPL, MSFT." :: String)]
                      ]
                , "required" .= (["symbol"] :: [String])
                , "additionalProperties" .= False
                ]
          ]
    ]

refreshTradingQuotesTool :: Value
refreshTradingQuotesTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("refresh_trading_quotes" :: String)
          , "description" .= ("Refresh live Alpaca quotes for the current AI Trading watchlist and re-render the trading panel." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties" .= object []
                , "additionalProperties" .= False
                ]
          ]
    ]

buildJsonRequest :: AiProviderConfig -> String -> Bool -> Value -> IO Request
buildJsonRequest config apiKey wantsStream payload = do
  request <- parseRequest (providerBaseUrl config <> "/chat/completions")
  pure (applyRequest config apiKey wantsStream payload request)

buildStreamingRequest :: AiProviderConfig -> String -> Value -> IO Request
buildStreamingRequest config apiKey payload = do
  request <- parseRequest (providerBaseUrl config <> "/chat/completions")
  pure (applyRequest config apiKey True payload request)

applyRequest :: AiProviderConfig -> String -> Bool -> Value -> Request -> Request
applyRequest config apiKey wantsStream payload request =
  request
    { method = "POST"
    , requestBody = RequestBodyLBS (encode payload)
    , requestHeaders =
        [ ("Authorization", BS8.pack ("Bearer " <> apiKey))
        , ("Content-Type", "application/json")
        , ("Accept", if wantsStream then "text/event-stream" else "application/json")
        ]
          <> openRouterHeaders config
    }

openRouterHeaders :: AiProviderConfig -> RequestHeaders
openRouterHeaders config =
  catMaybes
    [ fmap (\value -> ("HTTP-Referer" :: HeaderName, BS8.pack value)) (providerReferer config)
    , fmap (\value -> ("X-Title" :: HeaderName, BS8.pack value)) (providerTitle config)
    ]

readStreamingBody :: Response BodyReader -> IO String
readStreamingBody response = do
  chunks <- collect []
  pure (decodeUtf8 (LBS.toStrict (Builder.toLazyByteString (mconcat (reverse chunks)))))
  where
    collect acc = do
      chunk <- brRead (responseBody response)
      if BS8.null chunk
        then pure acc
        else collect (Builder.byteString chunk : acc)

consumeSse :: Response BodyReader -> String -> String -> (String -> IO ()) -> IO (Either String String)
consumeSse response buffer fullText onDelta = do
  chunk <- brRead (responseBody response)
  if BS8.null chunk
    then pure (Right fullText)
    else do
      let input = buffer <> decodeUtf8 chunk
          (linesNow, nextBuffer) = completeLines input
      nextFull <- foldM handleLine fullText linesNow
      if errorPrefix `isPrefixOf` nextFull
        then pure (Left (drop (length errorPrefix) nextFull))
        else consumeSse response nextBuffer nextFull onDelta
  where
    errorPrefix = "__STREAM_ERROR__:" :: String

    handleLine acc line =
      case stripPrefix "data: " (trim line) of
        Nothing -> pure acc
        Just "[DONE]" -> pure acc
        Just payload ->
          case eitherDecode (LBS.fromStrict (Text.encodeUtf8 (Text.pack payload))) of
            Left err -> pure ("__STREAM_ERROR__:" <> err)
            Right chunkValue -> do
              let deltas = chunkDeltas chunkValue
              mapM_ onDelta deltas
              pure (acc <> concat deltas)

chunkDeltas :: ChatChunk -> [String]
chunkDeltas (ChatChunk choices) =
  mapMaybe (\(ChunkChoice content) -> content) choices

completeLines :: String -> ([String], String)
completeLines input =
  case reverse input of
    '\n' : _ -> (lines input, "")
    _ ->
      let parts = lines input
       in case parts of
            [] -> ([], input)
            _ -> (init parts, last parts)

decodeUtf8 :: BS8.ByteString -> String
decodeUtf8 =
  Text.unpack . Text.decodeUtf8With Text.lenientDecode

trim :: String -> String
trim =
  Text.unpack . Text.strip . Text.pack
