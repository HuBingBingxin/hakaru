-- module Tests.TestSuite(main) where

import System.Exit (exitFailure)
import System.Environment (lookupEnv)

import qualified Tests.Parser       as P
import qualified Tests.TypeCheck    as TC
import qualified Tests.Simplify     as S
import qualified Tests.Disintegrate as D
import qualified Tests.Sample       as E
import qualified Tests.RoundTrip    as RT

import Test.HUnit

-- master test suite

ignored :: Assertion
ignored = putStrLn "Warning: maple tests will be ignored"

simplifyTests :: Maybe String -> Test
simplifyTests env =
  case env of
    Just _  -> S.allTests
    Nothing -> test ignored

allTests :: Maybe String -> Test
allTests env = test
  [ TestLabel "Parser"       P.allTests
  , TestLabel "TypeCheck"    TC.allTests
  , TestLabel "Simplify"     (simplifyTests env)
  , TestLabel "Disintegrate" D.allTests
  , TestLabel "Evaluate"     E.allTests
  , TestLabel "RoundTrip"    RT.allTests
  ]

--t1 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
--t1 = uniform_0_1 >>= \x -> factor (unsafeProb x)

--t5 :: (ABT Term abt) => abt '[] ('HMeasure HUnit)
--t5 = factor half >> dirac unit

main :: IO ()
main  = do
    env <- lookupEnv "LOCAL_MAPLE"
    Counts _ _ e f <- runTestTT (allTests env)
    if (e>0) || (f>0) then exitFailure else return ()
