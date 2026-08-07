module PageFactory.Clients.Model
  ( Client (..)
  , ClientTab (..)
  ) where

-- Client domain model and client-local tab names.

data Client = Client
  { clientId :: Int
  , clientName :: String
  , clientEmail :: String
  , clientBalance :: Int
  }
  deriving (Show)

data ClientTab = OverviewTab | InvoicesTab | ActivityTab | AiTab
  deriving (Eq, Show)
