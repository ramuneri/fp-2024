{-# OPTIONS_GHC -Wno-unused-do-bind #-}
module ClientDSL where

import Control.Lens ((^.))
import Data.List (intercalate)
import Control.Monad.Free (Free(..), liftF)
import Control.Exception (try, SomeException)
import qualified Data.ByteString.Lazy.Char8 as L
import Network.Wreq (post, responseBody, Response)

-- Program a - a sequence of commands from CommandDSL
-- Free - how sequence of operations will be executed
-- CommandDSL - dt that represents the set of opperations available in this DSL
type Program = Free CommandDSL

-- DSL supports these commands
data CommandDSL a
    = AddAnimal String String Int a
    | DeleteAnimal String String Int a
    | ListAnimals ([String] -> a)
    | SaveState a
    | LoadState (String -> a)

-- functor instance; free needs fmap to chain opperations
instance Functor CommandDSL where
    fmap f (AddAnimal sp n a next) = AddAnimal sp n a (f next) -- applies function f to next
    fmap f (DeleteAnimal sp n a next) = DeleteAnimal sp n a (f next)
    fmap f (ListAnimals next) = ListAnimals (f . next)
    fmap f (SaveState next) = SaveState (f next)
    fmap f (LoadState next) = LoadState (f . next)


addAnimal :: String -> String -> Int -> Program ()
addAnimal sp n a = liftF $ AddAnimal sp n a ()

deleteAnimal :: String -> String -> Int -> Program ()
deleteAnimal sp n a = liftF $ DeleteAnimal sp n a ()

listAnimals :: Program [String]
listAnimals = liftF $ ListAnimals id

saveState :: Program ()
saveState = liftF $ SaveState ()

loadState :: Program String
loadState = liftF $ LoadState id

-- goes through entire Program (from app4-client) structure
-- cmds - so far processed commands to strings
-- res - final result
interpretBatch :: Program a -> String
interpretBatch program = let (commands, _) = runBatch program 
                         in intercalate ";\n" commands ++ "\nEND"
  where
    runBatch :: Program a -> ([String], Maybe a)
    runBatch (Free (AddAnimal sp n a next)) =
        let (cmds, res) = runBatch next
         in (("ADD " ++ sp ++ " " ++ n ++ " " ++ show a) : cmds, res)
    runBatch (Free (DeleteAnimal sp n a next)) =
        let (cmds, res) = runBatch next
         in (("DELETE " ++ sp ++ " " ++ n ++ " " ++ show a) : cmds, res)
    runBatch (Free (ListAnimals _)) =
        (["LIST"], Nothing)
    runBatch (Free (SaveState next)) =
        let (cmds, res) = runBatch next
         in ("SAVE" : cmds, res)
    runBatch (Free (LoadState _)) =
        (["LOAD"], Nothing)
    runBatch (Pure a) = ([], Just a)

interpretOneByOne :: Program a -> IO [String]
interpretOneByOne (Free (AddAnimal sp n a next)) = do
    sendBatch $ "ADD " ++ sp ++ " " ++ n ++ " " ++ show a
    interpretOneByOne next
interpretOneByOne (Free (DeleteAnimal sp n a next)) = do
    sendBatch $ "DELETE " ++ sp ++ " " ++ n ++ " " ++ show a
    interpretOneByOne next
interpretOneByOne (Free (ListAnimals next)) = do
    res <- sendBatch "LIST"
    let animalList = lines res
    interpretOneByOne (next animalList)
interpretOneByOne (Free (SaveState next)) = do
    sendBatch "SAVE"
    interpretOneByOne next
interpretOneByOne (Free (LoadState next)) = do
    res <- sendBatch "LOAD"
    interpretOneByOne (next res)
interpretOneByOne (Pure _) = return []

sendBatch :: String -> IO String
sendBatch batchRequest = do
    let url = "http://localhost:3000"
    let batchRequestBody = L.pack batchRequest
    result <- try $ post url batchRequestBody :: IO (Either SomeException (Response L.ByteString))
    return $ case result of
        Left ex -> "Error: " ++ show ex
        Right response -> L.unpack (response ^. responseBody)
