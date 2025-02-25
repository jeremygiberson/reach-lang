{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

{-# OPTIONS_GHC -Wno-missing-export-lists #-}

module Reach.Simulator.Server where

import Reach.AST.LL
import Reach.Util
import Control.Monad.Reader
import qualified Reach.Simulator.Core as C
import Control.Concurrent.STM
import Data.Default.Class
import Data.Text.Lazy (Text)
import Network.Wai.Middleware.RequestLogger
import Web.Scotty.Trans
import qualified Data.Map.Strict as M
import GHC.Generics
import Data.Aeson (FromJSON, ToJSON)

instance Default Session where
  def = initSession

newtype WebM a = WebM { runWebM :: ReaderT (TVar Session) IO a }
  deriving newtype (Applicative, Functor, Monad, MonadIO, MonadReader (TVar Session))

webM :: MonadTrans t => WebM a -> t WebM a
webM = lift

gets :: (Session -> b) -> WebM b
gets f = ask >>= liftIO . readTVarIO >>= return . f

modify :: (Session -> Session) -> WebM ()
modify f = ask >>= liftIO . atomically . flip modifyTVar' f

type StateId = Int
type ActionId = Int

portNumber :: Int
portNumber = 3001

type Graph = M.Map StateId C.State

data Status = Initial | Running | Done
  deriving (Show, Generic)

instance ToJSON Status
instance FromJSON Status

data Session = Session
  { e_actors_actions :: M.Map C.ActorId [ActionId]
  , e_nsid :: Int
  , e_naid :: Int
  , e_ids_actions :: M.Map ActionId C.Action
  , e_actor_id :: C.ActorId
  , e_graph :: Graph
  , e_src :: Maybe LLProg
  , e_status :: Status
  , e_edges :: [(StateId,StateId)]
  }

initSession :: Session
initSession = Session
  { e_actors_actions = mempty
  , e_nsid = 0
  , e_naid = 0
  , e_ids_actions = mempty
  , e_actor_id = C.consensusId
  , e_graph = mempty
  , e_src = Nothing
  , e_status = Initial
  , e_edges = mempty
  }

processNewState :: Maybe (StateId) -> C.PartState -> WebM ()
processNewState psid ps = do
  sid <- gets e_nsid
  actorId <- gets e_actor_id
  edges <- gets e_edges
  _ <- case ps of
    C.PS_Done _ _ -> do
      _ <- return $ putStrLn "EVAL DONE"
      registerAction actorId C.A_None
    C.PS_Suspend a _ _ -> registerAction actorId a
  let ((g,l), stat) =
        case ps of
          C.PS_Done s _ -> (s, Done)
          C.PS_Suspend _ s _ -> (s, Running)
  graph <- gets e_graph
  let locals = C.l_locals l
  let lcl = saferMapRef "processNewState" $ M.lookup actorId locals
  let lcl' = lcl { C.l_ks = Just ps }
  let l' = l { C.l_locals = M.insert actorId lcl' locals }
  modify $ \ st -> st
    {e_nsid = sid + 1}
    {e_status = stat}
    {e_graph = M.insert sid (g,l') graph}
  case psid of
    Nothing -> return ()
    Just psid' -> modify $ \ st -> st
      {e_edges = (psid',sid):edges}

registerAction :: C.ActorId -> C.Action -> WebM ActionId
registerAction actorId act = do
  aid <- gets e_naid
  modify $ \ st -> st {e_naid = aid + 1}
  actacts <- gets e_actors_actions
  idacts <- gets e_ids_actions
  modify $ \ st -> st {e_ids_actions = M.insert aid act idacts}
  case M.lookup actorId actacts of
    Nothing -> modify $ \ st -> st {e_actors_actions = M.insert actorId [aid] actacts }
    Just acts -> modify $ \ st -> st {e_actors_actions = M.insert actorId (aid:acts) actacts }
  return aid

unblockProg :: StateId -> ActionId -> C.DLVal -> WebM ()
unblockProg sid aid v = do
  graph <- gets e_graph
  actorId <- gets e_actor_id
  avActions <- gets e_ids_actions
  case M.lookup sid graph of
    Nothing -> do
      possible "previous state not found"
    Just (g,l') -> do
      let locals = C.l_locals l'
      case C.l_ks <$> M.lookup actorId locals of
        Nothing -> do
          possible "actor not found"
        Just Nothing -> do
          possible $ "partstate not found for actor "
            <> show actorId
            <> " in: "
            <> (show $ M.keys locals)
        Just (Just (C.PS_Suspend _a (_g,_l) k)) -> do
          let l = l' {C.l_curr_actor_id = actorId}
          case M.lookup aid avActions of
            Just (C.A_Interact _at _slcxtframes _part _str _dltype _args) -> do
              let ps = k (g,l) v
              processNewState (Just sid) ps
            Just (C.A_InteractV _part _str _dltype) -> do
              let ps = k (g,l) v
              processNewState (Just sid) ps
            Just (C.A_Contest _phid) -> do
              let ps = k (g,l) v
              processNewState (Just sid) ps
            Just (C.A_TieBreak _poolid _parts) -> do
              let ps = k (g,l) v
              processNewState (Just sid) ps
            Just C.A_None -> do
              let ps = k (g,l) v
              processNewState (Just sid) ps
            Just (C.A_AdvanceTime n)  -> do
              case ((C.e_nwtime g) < n) of
                True -> do
                  let ps = k (g{C.e_nwtime = n},l) v
                  processNewState (Just sid) ps
                False -> do
                  let ps = k (g,l) v
                  processNewState (Just sid) ps
            Just (C.A_AdvanceSeconds n)  -> do
              case ((C.e_nwsecs g) < n) of
                True -> do
                  let ps = k (g{C.e_nwsecs = n},l) v
                  processNewState (Just sid) ps
                False -> do
                  let ps = k (g,l) v
                  processNewState (Just sid) ps
            Nothing -> possible "action not found"
        Just (Just (C.PS_Done _ _)) -> do
          possible "previous state already terminated"

allStates :: WebM [StateId]
allStates = do
  a <- gets e_nsid
  return [0..(a-1)]

getStatus :: WebM Status
getStatus = do
  s <- gets e_status
  return s

getEdges :: WebM [(StateId,StateId)]
getEdges = do
  es <- gets e_edges
  return es

getProgState :: StateId -> WebM (Maybe C.State)
getProgState sid = do
  s <- gets e_graph
  case M.lookup sid s of
    Nothing -> return Nothing
    Just st -> return $ Just st

changeActor :: C.ActorId -> WebM ()
changeActor actId = do
  modify $ \ st -> st {e_actor_id = actId}

computeActions :: WebM [C.Action]
computeActions = do
  actacts <- gets e_actors_actions
  idacts <- gets e_ids_actions
  let acts = concat $ map (take 1) $ M.elems actacts
  return $ map (\x -> saferMapRef "computeActions" $ M.lookup x idacts) acts

initProgSim :: LLProg -> WebM ()
initProgSim ll = do
  let initSt = C.initState
  ps <- return $ C.initApp ll initSt
  processNewState Nothing ps

initProgSimFor :: C.ActorId -> StateId -> LLProg -> WebM ()
initProgSimFor actId sid (LLProg _ _ _ _ _ _ _ _ step) = do
  graph <- gets e_graph
  modify $ \ st -> st {e_actor_id = actId }
  let (g,l) = saferMapRef "initProgSimFor" $ M.lookup sid graph
  let l' = l { C.l_curr_actor_id = actId }
  ps <- return $ C.initAppFromStep step (g,l')
  processNewState (Just sid) ps

startServer :: LLProg -> IO ()
startServer p = do
  sync <- newTVarIO def
  let runActionToIO m = runReaderT (runWebM m) sync
  putStrLn "Starting Sim Server..."
  scottyT portNumber runActionToIO (app p)

setHeaders :: ActionT Text WebM ()
setHeaders = do
  setHeader "Access-Control-Allow-Origin" "*"
  setHeader "Access-Control-Allow-Credentials" "true"
  setHeader "Access-Control-Allow-Methods" "GET, POST, PUT"
  setHeader "Access-Control-Allow-Headers" "Content-Type"

app :: LLProg -> ScottyT Text WebM ()
app p = do
  middleware logStdoutDev

  post "/load" $ do
    setHeaders
    webM $ modify $ \ st -> st {e_src = Just p}
    json $ ("OK" :: String)

  post "/init" $ do
    setHeaders
    ll <- webM $ gets e_src
    case ll of
      Nothing -> json $ ("No Program" :: String)
      Just ll' -> do
        webM $ initProgSim ll'
        json $ ("OK" :: String)

  post "/init/:a/:s" $ do
    setHeaders
    a <- param "a"
    s <- param "s"
    ll <- webM $ gets e_src
    case ll of
      Nothing -> json $ ("No Program" :: String)
      Just ll' -> do
        webM $ initProgSimFor a s ll'
        json $ ("OK" :: String)

  get "/states" $ do
    setHeaders
    ss <- webM $ allStates
    json ss

  get "/edges" $ do
    setHeaders
    es <- webM $ getEdges
    json es

  get "/global/:s" $ do
    setHeaders
    s <- param "s"
    g' <- webM $ getProgState s
    case g' of
      Nothing -> json $ ("Not Found" :: String)
      Just (g,_) -> json g

  get "/local/:s" $ do
    setHeaders
    s <- param "s"
    l' <- webM $ getProgState s
    case l' of
      Nothing -> json $ ("Not Found" :: String)
      Just (_,l) -> json l

  get "/status" $ do
    setHeaders
    ss <- webM $ getStatus
    json ss

  get "/states/:s" $ do
    setHeaders
    s <- param "s"
    ss <- webM $ allStates
    json (filter ((==) s) $ ss)

  get "/actions" $ do
    setHeaders
    as <- webM $ computeActions
    json as

  post "/states/:s/actions/:a/" $ do
    setHeaders
    s <- param "s"
    a <- param "a"
    v :: Integer <- param "data"
    ps <- M.fromList <$> params
    case M.lookup "who" ps of
      Nothing -> return ()
      Just prm -> do
        case (parseParam prm) :: Either Text C.ActorId of
          Left e -> possible $ show e
          Right w -> webM $ changeActor $ fromIntegral w
    webM $ unblockProg s a $ C.V_UInt v
    json ("OK" :: String)

  get "/ping" $ do
    setHeaders
    json ("Hello World" :: String)

  options (regex ".*") $ do
    setHeaders
    json ("OK" :: String)
