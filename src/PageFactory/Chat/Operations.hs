{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Chat.Operations
  ( OperationArg (..)
  , entityOperationContext
  , fragmentRenderedEvent
  , navigateEvent
  , operationToolSchema
  , stateUpdatedEvent
  ) where

-- Helpers for building entity operation tools and common UI events.

import Data.Aeson (Value, object, (.=))
import qualified Data.Aeson.Key as Key
import Data.Aeson.Types (Pair)
import PageFactory.Chat.Extension (ToolSchema)

data OperationArg = OperationArg
  { operationArgName :: String
  , operationArgDescription :: String
  , operationArgRequired :: Bool
  }
  deriving (Eq, Show)

operationToolSchema :: String -> String -> [OperationArg] -> ToolSchema
operationToolSchema name description args =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= name
          , "description" .= description
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties" .= object (map argProperty args)
                , "required" .= map operationArgName (filter operationArgRequired args)
                , "additionalProperties" .= False
                ]
          ]
    ]

argProperty :: OperationArg -> Pair
argProperty arg =
  Key.fromString (operationArgName arg)
    .= object
      [ "type" .= ("string" :: String)
      , "description" .= operationArgDescription arg
      ]

fragmentRenderedEvent :: String -> String -> String -> (String, Value)
fragmentRenderedEvent target label html =
  ( "fragment.rendered"
  , object
      [ "target" .= target
      , "label" .= label
      , "html" .= html
      ]
  )

navigateEvent :: String -> String -> String -> (String, Value)
navigateEvent url label note =
  ( "ui.action"
  , object
      [ "action" .= ("navigate" :: String)
      , "url" .= url
      , "label" .= label
      , "note" .= note
      ]
  )

stateUpdatedEvent :: [Pair] -> (String, Value)
stateUpdatedEvent fields =
  ("state.updated", object fields)

entityOperationContext :: String -> String -> String -> [String] -> String
entityOperationContext entity route fragmentSlot operations =
  unlines
    [ "Entity operations: " <> entity
    , "Entity route: " <> route
    , "Entity fragment slot: " <> fragmentSlot
    , "Entity capabilities: " <> unwords operations
    , "Use refresh operations when the entity is already visible and only the fragment needs to be redrawn."
    ]
