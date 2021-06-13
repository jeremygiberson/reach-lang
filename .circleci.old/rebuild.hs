#!/usr/bin/env stack
{- stack script
 --compile
 --ghc-options -Wall
 --resolver    lts-17.8
 --package     bytestring
 --package     containers
 --package     dhall
 --package     dhall-json
 --package     dhall-yaml
 --package     directory
 --package     filepath
 --package     process
 --package     text
 -}

{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications  #-}

import Control.Monad      (filterM)
import Data.List          (nub, sort)
import Data.Void          (Void)
import Dhall              (Generic, ToDhall, FromDhall, auto, embed, expected, inject)
import Dhall.Core         (Expr)
import Dhall.JSON         (omitEmpty)
import Dhall.Pretty       (prettyExpr)
import Dhall.Yaml         (Options(..), defaultOptions, dhallToYaml)
import GHC.IO.Encoding    (setLocaleEncoding, utf8)
import System.Directory   (listDirectory, doesDirectoryExist)
import System.Environment (getExecutablePath)
import System.FilePath    ((</>), takeDirectory)
import System.Process     (readCreateProcess, shell, cwd)

import qualified Data.ByteString as B
import qualified Data.Map.Strict as M
import qualified Data.Text       as T
import qualified Data.Text.IO    as T


data Connector
  = ALGO
  | CFX
  | ETH
  deriving (Show, Generic, ToDhall, FromDhall)


textOf :: Expr s Void -> T.Text
textOf = T.pack . show . prettyExpr


renderExamples :: M.Map FilePath [Connector] -> T.Text
renderExamples es = T.intercalate "\n\n"
  [ "-- Code generated by `rebuild` script.  DO NOT EDIT."
  , "let Connector = " <> cs -- Encode the `Connector` union type
  , "let examples =\n" <> es''
  , "in { Connector, examples }\n"
  ]
 where
  cs   = textOf . maximum . expected $ auto @Connector
  es'  = textOf $ embed inject es
  es'' = "  " <> (T.intercalate "\n  " $ T.lines es')


skipEth :: [FilePath]
skipEth =
  [ "tut-7-rpc"
  ]


skipAlgo :: [FilePath]
skipAlgo =
  [ "tut-7-rpc"
  ]


skipCfx :: [FilePath]
skipCfx =
  [ "tut-7-rpc" -- TODO: test rpc w/ cfx
  , "tut-8" -- TODO: add cfx to tut-8

  -- Tx with same nonce already inserted.
  , "multiple-pr-case"
  , "popularity-contest"
  , "raffle"
  , "rent-seeking"
  , "workshop-fomo"
  , "workshop-fomo-generalized"

  -- data: '"tx already exist"'
  , "nft-auction"
  , "workshop-trust-fund"

  -- Transaction ${txn} is discarded due to a too stale nonce
  , "nft-dumb"

  -- Conflux.sendTransaction: ParseError `data` 'does not match "hex"'
  , "atomic-swap"
  , "atomic-swap-auction"
  , "remote"
  , "weird-swap"

  -- View stuff. "Error: null"
  , "view-bytes"
  , "view-fun"
  , "view-map"
  , "view-maybe"
  , "view-steps"

  -- Map stuff. "Invalid parameters: tx"
  , "map-any"
  , "map-big"
  , "map-multi"
  , "map-rwrw"
  , "map-sender"
  , "map-vary"

  -- expected Some, got None
  , "zbeq"

  -- nondeterministic failures
  -- RPCError: Error processing request: Filter error: Block ${blockId} is not executed yet
  -- index.mjs > B > recv > Provider.getLogs > Conflux.getLogs
  -- https://app.circleci.com/pipelines/github/reach-sh/reach-lang/2590/workflows/617f4fd2-6125-47e6-b1e8-e1bd32fd5671/jobs/19113
  , "ttt"

  ]


skipExample :: [FilePath]
skipExample =
  [ "tut-7-rpc"

  -- nondeterministic failures on CI
  -- https://trello.com/c/X8c2lhSV/1273-fix-tut-8-non-deterministic-failures-in-ci
  , "tut-8"
  ]


connectors :: FilePath -> [Connector]
connectors f =
     (if f `elem` skipEth  then [] else [ ETH  ])
  <> (if f `elem` skipAlgo then [] else [ ALGO ])
  <> (if f `elem` skipCfx  then [] else [ CFX  ])


main :: IO ()
main = do
  -- https://github.com/dhall-lang/dhall-haskell/blob/46432f2/dhall-json/src/Dhall/DhallToYaml/Main.hs#L88
  setLocaleEncoding utf8

  circleci <- takeDirectory <$> getExecutablePath

  let o = defaultOptions { explain = False, noEdit = True, omission = omitEmpty }
  let c = circleci </> "config.dhall"
  let e = circleci </> "../examples"

  gits <- nub . (fmap takeDirectory) . lines
    <$> readCreateProcess ((shell "git ls-files") { cwd = Just e }) ""

  edirs <- listDirectory e
       >>= filterM (doesDirectoryExist . (e </>))
       >>= pure . sort . filter (\x -> x `elem` gits && not (x `elem` skipExample))

  let examples = M.fromList $ map (\x -> (x, connectors x)) edirs

  T.writeFile (circleci </> "examples.dhall") (renderExamples examples)

  config <- T.readFile c >>= dhallToYaml o (Just c)
  B.writeFile (circleci </> "config.yml") $ config <> "\n"