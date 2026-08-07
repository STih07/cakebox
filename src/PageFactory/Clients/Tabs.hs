module PageFactory.Clients.Tabs
  ( clientTabFromSlug
  , clientTabPath
  , clientTabTitle
  , clientTabs
  ) where

-- URL slugs and labels for client-local navigation tabs.

import PageFactory.Clients.Model (Client (..), ClientTab (..))

clientTabs :: [ClientTab]
clientTabs = [OverviewTab, InvoicesTab, ActivityTab, AiTab]

clientTabTitle :: ClientTab -> String
clientTabTitle OverviewTab = "Обзор"
clientTabTitle InvoicesTab = "Счета"
clientTabTitle ActivityTab = "Активность"
clientTabTitle AiTab = "AI"

clientTabSlug :: ClientTab -> String
clientTabSlug OverviewTab = "overview"
clientTabSlug InvoicesTab = "invoices"
clientTabSlug ActivityTab = "activity"
clientTabSlug AiTab = "ai"

clientTabFromSlug :: String -> Maybe ClientTab
clientTabFromSlug "overview" = Just OverviewTab
clientTabFromSlug "invoices" = Just InvoicesTab
clientTabFromSlug "activity" = Just ActivityTab
clientTabFromSlug "ai" = Just AiTab
clientTabFromSlug _ = Nothing

clientTabPath :: Client -> ClientTab -> String
clientTabPath client tabName =
  "/clients/" <> show (clientId client) <> "/" <> clientTabSlug tabName
