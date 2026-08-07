module Main where

-- Executable entrypoint: dispatch CLI commands to the app server.

import PageFactory.App.Server (generateStatic, serve)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["generate"] -> generateStatic
    ["serve"] -> serve
    [] -> serve
    _ -> do
      putStrLn "Usage: page-factory [serve|generate]"
      putStrLn "  serve    Run dynamic renderer on 127.0.0.1:8098"
      putStrLn "  generate Write static files into public/"

