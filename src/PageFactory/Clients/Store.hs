module PageFactory.Clients.Store
  ( loadClients
  ) where

-- Client data loading. CSV today, database stream later.

import Data.Char (isSpace)
import PageFactory.Clients.Model (Client (..))

loadClients :: FilePath -> IO [Client]
loadClients path = do
  contents <- readFile path
  pure (map parseClient (drop 1 (filter (not . blank) (lines contents))))
  where
    blank = all isSpace

parseClient :: String -> Client
parseClient line =
  case splitComma line of
    [rawId, name, email, rawBalance] ->
      Client
        { clientId = read (trim rawId)
        , clientName = trim name
        , clientEmail = trim email
        , clientBalance = read (trim rawBalance)
        }
    _ -> error ("Bad client row: " <> line)

splitComma :: String -> [String]
splitComma = splitOn ','

splitOn :: Char -> String -> [String]
splitOn delimiter = foldr step [""]
  where
    step c acc@(x : xs)
      | c == delimiter = "" : acc
      | otherwise = (c : x) : xs
    step _ [] = []

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

