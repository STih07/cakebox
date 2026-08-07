{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Engine.Http
  ( RenderMode (..)
  , htmlResponse
  , plainResponse
  , renderMode
  , renderTarget
  ) where

-- HTTP-facing helpers: full/fragment detection and WAI responses.

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Char (toLower)
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as LTE
import Network.HTTP.Types (Status, hContentType)
import Network.Wai (Request, Response, queryString, requestHeaders, responseLBS)
import PageFactory.Engine.Html (Html (..))

data RenderMode = FullDocument | FragmentOnly
  deriving (Eq, Show)

renderMode :: Request -> RenderMode
renderMode req
  | queryFlag "fragment" = FragmentOnly
  | queryFlag "partial" = FragmentOnly
  | headerIs "X-Render-Mode" ["fragment", "partial"] = FragmentOnly
  | headerIs "X-Requested-With" ["container", "fragment", "fetch"] = FragmentOnly
  | headerIs "HX-Request" ["true"] = FragmentOnly
  | otherwise = FullDocument
  where
    queryFlag name =
      case lookup name (queryString req) of
        Just Nothing -> True
        Just (Just value) -> lowerBS value `elem` ["1", "true", "yes"]
        Nothing -> False

    headerIs name expected =
      maybe False (\value -> lowerBS value `elem` expected) (lookup name (requestHeaders req))

renderTarget :: Request -> Maybe String
renderTarget req =
  case lookup "target" (queryString req) of
    Just (Just value) -> Just (lowerBS value)
    _ -> lowerBS <$> lookup "X-Render-Target" (requestHeaders req)

lowerBS :: ByteString -> String
lowerBS = map toLower . BS.unpack

htmlResponse :: Status -> Html -> Response
htmlResponse status body =
  responseLBS status [(hContentType, "text/html; charset=utf-8")] (encodeUtf8Lazy (renderHtml body))

plainResponse :: Status -> String -> Response
plainResponse status body =
  responseLBS status [(hContentType, "text/plain; charset=utf-8")] (encodeUtf8Lazy body)

encodeUtf8Lazy :: String -> LBS.ByteString
encodeUtf8Lazy = LTE.encodeUtf8 . LT.pack

