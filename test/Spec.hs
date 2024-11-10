{-# LANGUAGE ImportQualifiedPost #-}


import Test.Tasty ( TestTree, defaultMain, testGroup )
import Test.Tasty.HUnit ( testCase, (@?=) )
import Test.Tasty.QuickCheck as QC
import Test.QuickCheck (Gen, forAll, elements, oneof, choose, listOf1)


import Data.List (sort)
import Data.Ord ()

import Lib1 qualified
import Lib2 qualified
import Lib3 qualified

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [unitTests, propertyTests]

unitTests :: TestTree
unitTests = testGroup "Lib2 tests"
  [
    -- No need for 'Animal' tests bc it is just data type

    -- No need for 'Query' tests bc it is just data type


    -- for parseAnimal
    testCase "parseAnimal valid input" $
      Lib2.parseAnimal "monkey Ben 6" @?=
        Right (Lib2.Animal {Lib2.species = "monkey", Lib2.name = "Ben", Lib2.age = 6}),

    testCase "parseAnimal valid input with extra spaces" $
      Lib2.parseAnimal "dog  Max   5  " @?=
        Right (Lib2.Animal {Lib2.species = "dog", Lib2.name = "Max", Lib2.age = 5}),

    testCase "parseAnimal invalid input" $
      Lib2.parseAnimal "12345 Ben 6" @?=
        Left "12345 Ben 6 does not start with an alphabetic character",


    -- for parseChar
    testCase "parseChar valid input" $
      Lib2.parseChar 'n' "number 5" @?= 
        Right "umber 5",

    testCase "parseChar invalid input" $
      Lib2.parseChar 'i' "number 5" @?=
        Left "Expected i but got n",


    -- for parseString
    testCase "parseString valid input" $
      Lib2.parseString "Animal shelter" @?=
        Right ("Animal", " shelter"),

    testCase "parseString invalid input" $
      Lib2.parseString "123abc" @?=
        Left "123abc does not start with an alphabetic character",


    -- for parseNumber
    testCase "parseNumber valid input" $
      Lib2.parseNumber "123abc" @?=
        Right (123, "abc"),

    testCase "parseNumber invalid input" $
      Lib2.parseNumber "abc123" @?=
        Left "abc123 does not start with a digit",


    -- -- for parseQuery     
    testCase "parseQuery valid input for LIST command" $
      Lib2.parseQuery "LIST" @?=
        Right Lib2.ListAnimals,

    testCase "parseQuery valid input for ADD command" $
      Lib2.parseQuery "ADD cat Tom 3" @?=
        Right (Lib2.Add (Lib2.Animal "cat" "Tom" 3)),

    testCase "parseQuery valid input for DELETE command" $
      Lib2.parseQuery "DELETE dog Max 5" @?=
        Right (Lib2.Delete (Lib2.Animal "dog" "Max" 5)),

    testCase "parseQuery invalid command" $
      Lib2.parseQuery "bad_command" @?=
        Left "Expected D but got b",

    -- using CompoundQuery
    testCase "parseQuery valid input for compound query" $
      Lib2.parseQuery "ADD cat Tom 3; DELETE dog Max 5" @?=
        Right (Lib2.CompoundQuery 
                (Lib2.Add (Lib2.Animal "cat" "Tom" 3)) 
                (Lib2.Delete (Lib2.Animal "dog" "Max" 5))),


    -- for parseCompoundQuery
    testCase "parseCompoundQuery valid input" $
      Lib2.parseCompoundQuery "ADD cat Tom 3; DELETE dog Max 5" @?=
        Right (Lib2.CompoundQuery 
                (Lib2.Add (Lib2.Animal "cat" "Tom" 3)) 
                (Lib2.Delete (Lib2.Animal "dog" "Max" 5))),

    testCase "parseCompoundQuery valid input - nested compound query" $
      Lib2.parseCompoundQuery "ADD cat Tom 3; ADD dog Max 5; DELETE dog Max 5; ADD fish Jem 1" @?=
        Right (Lib2.CompoundQuery 
                (Lib2.Add (Lib2.Animal "cat" "Tom" 3))
                (Lib2.CompoundQuery 
                  (Lib2.Add (Lib2.Animal "dog" "Max" 5))
                  (Lib2.CompoundQuery 
                    (Lib2.Delete (Lib2.Animal "dog" "Max" 5))
                    (Lib2.Add (Lib2.Animal "fish" "Jem" 1))))),

    testCase "parseCompoundQuery invalid input - empty second command" $
      Lib2.parseCompoundQuery "ADD cat Tom 3;" @?=
        Left "Expected some command but did not get anything",


    -- for parseAdd
    testCase "ADD valid" $
      Lib2.parseAdd "ADD cat Luna 3" @?= 
        Right (Lib2.Add (Lib2.Animal "cat" "Luna" 3)),

    testCase "ADD invalid" $
      Lib2.parseAdd "ADD Juppy 15" @?= 
        Left "15 does not start with an alphabetic character",


    -- for parseDelete
    testCase "DELETE valid" $
      Lib2.parseDelete "DELETE dog Max 5" @?= 
        Right (Lib2.Delete (Lib2.Animal "dog" "Max" 5)),

    testCase "DELETE invalid" $
      Lib2.parseDelete "DELETE dog 5" @?= 
        Left "5 does not start with an alphabetic character",


    -- No need for 'State' test bc it is just data type


    -- for emptyState and stateTransition
    testCase "StateTransition: starts with emptyState, add animal" $
      case Lib2.stateTransition Lib2.emptyState (Lib2.Add (Lib2.Animal "dog" "Max" 5)) of
        Right (msg, Lib2.State animals) -> do
          msg @?= Just "Added animal: Animal {species = \"dog\", name = \"Max\", age = 5}"
          animals @?= [Lib2.Animal "dog" "Max" 5]
        _ -> error "Test failed: adding an animal did not work as expected",

    testCase "StateTransition: starts with not an emptyState, add animal" $
      let initialState = Lib2.State [Lib2.Animal "cat" "Tom" 3]
      in case Lib2.stateTransition initialState (Lib2.Add (Lib2.Animal "dog" "Max" 5)) of
        Right (msg, Lib2.State animals) -> do
          msg @?= Just "Added animal: Animal {species = \"dog\", name = \"Max\", age = 5}"
          animals @?= [Lib2.Animal "dog" "Max" 5, Lib2.Animal "cat" "Tom" 3]
        _ -> error "Test failed: adding an animal to a non-empty state did not work as expected",

    testCase "StateTransition: add animal that already exists" $
      let initialState = Lib2.State [Lib2.Animal "dog" "Max" 5]
      in case Lib2.stateTransition initialState (Lib2.Add (Lib2.Animal "dog" "Max" 5)) of
        Left err -> err @?= "Animal Animal {species = \"dog\", name = \"Max\", age = 5} already exists."
        _ -> error "Test failed: should not add an animal that already exists",

    testCase "StateTransition: delete animal from non-empty state" $
      let initialState = Lib2.State [Lib2.Animal "dog" "Max" 5]
      in case Lib2.stateTransition initialState (Lib2.Delete (Lib2.Animal "dog" "Max" 5)) of
        Right (msg, Lib2.State animals) -> do
          msg @?= Just "Deleted animal: Animal {species = \"dog\", name = \"Max\", age = 5}"
          animals @?= []
        _ -> error "Test failed: deleting an animal did not work as expected",

    testCase "StateTransition: delete animal that does not exist" $
      let initialState = Lib2.State [Lib2.Animal "cat" "Tom" 3]
      in case Lib2.stateTransition initialState (Lib2.Delete (Lib2.Animal "dog" "Max" 5)) of
        Left err -> err @?= "Animal Animal {species = \"dog\", name = \"Max\", age = 5} not found."
        _ -> error "Test failed: should not delete an animal that does not exist",

    testCase "StateTransition: list animals in empty state" $
      case Lib2.stateTransition Lib2.emptyState Lib2.ListAnimals of
        Right (msg, _) -> msg @?= Just "No animals found."
        _ -> error "Test failed: listing animals in empty state did not work as expected",

    testCase "StateTransition: list animals in non-empty state" $
      let stateWithAnimals = Lib2.State [Lib2.Animal "dog" "Max" 5, Lib2.Animal "cat" "Tom" 3]
      in case Lib2.stateTransition stateWithAnimals Lib2.ListAnimals of
        Right (msg, _) -> msg @?= Just "Current animals: [Animal {species = \"dog\", name = \"Max\", age = 5},Animal {species = \"cat\", name = \"Tom\", age = 3}]"
        _ -> error "Test failed: listing animals did not work as expected"
  ]


-- "We will generate possible Statements, render them into text, and then 
-- check whether we get back the same Statements when we parse it back"

-- small generators
genSpecies :: Gen String
genSpecies = elements ["dog", "cat", "hamster", "fish", "bird"]

genName :: Gen String
genName = elements ["Tom", "Max", "Jem", "Whiskers"]

genAge :: Gen Int
genAge = choose (1, 25)


-- larger generators
genAnimal :: Gen Lib2.Animal
genAnimal = do
    species <- genSpecies
    name <- genName
    age <- genAge
    return $ Lib2.Animal species name age

genQuery :: Gen Lib2.Query -- for individual Queries
genQuery = oneof
    [ Lib2.Add <$> genAnimal
    , Lib2.Delete <$> genAnimal
    , return Lib2.ListAnimals
    , Lib2.CompoundQuery <$> genQuery <*> genQuery
    ]

genStatements :: Gen Lib3.Statements
genStatements = oneof
    [ Lib3.Single <$> genQuery
    , Lib3.Batch <$> listOf1 genQuery  -- can i use `listOf1` (build in)?
    ]

-- cor testing for render/parse round-trip
prop_renderParseRoundTrip :: Property
prop_renderParseRoundTrip = forAll genStatements $ \statements ->
    let rendered = Lib3.renderStatements statements
        parsed = Lib3.parseStatements rendered
    in parsed == Right (statements, "")

propertyTests :: TestTree
propertyTests = testGroup "Property-based tests"
  [
    QC.testProperty "sort == sort . reverse" $
      \list -> sort (list :: [Int]) == sort (reverse list),
    
    QC.testProperty "Render/Parse round-trip for Statements" prop_renderParseRoundTrip
  ]
  
