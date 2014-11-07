{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, ScopedTypeVariables #-}
{-# LANGUAGE DeriveDataTypeable, GADTs, Rank2Types, StandaloneDeriving #-}
{-# OPTIONS -W -fno-warn-warnings-deprecations -fno-warn-unused-binds #-}

module Language.Hakaru.Maple (Maple(..), runMaple, Any(..), closeLoop) where

-- Maple printing interpretation

import Prelude hiding (Real)
import Language.Hakaru.Syntax (Order(..), Base(..), Integrate(..), Lambda(..),
    TypeOf(Sum, One), typeOf, typeOf1, typeOf2)
import Data.Ratio
import Data.Typeable (Typeable1)
import Control.Monad (liftM2)
import Control.Monad.Trans.Reader (ReaderT(ReaderT), runReaderT)
import Control.Monad.Trans.Cont (Cont, cont, runCont)
import Language.Hakaru.PrettyPrint (runPrettyPrint) -- just for testing closeLoop

import Language.Haskell.Interpreter hiding (typeOf)

newtype Maple a = Maple { unMaple :: ReaderT Int (Cont String) String }

-- "piecewise" in Maple only works when the expression has numeric type.
-- So "runMaple" should only be used when the expression has numeric type.
runMaple :: Maple a -> Int -> String
runMaple (Maple x) i = runCont (runReaderT x i) id

mapleFun1 :: String -> Maple a -> Maple b
mapleFun1 fn (Maple x) =
  Maple (fmap (\y -> fn ++ "(" ++ y ++ ")") x)

mapleFun2 :: String -> Maple a -> Maple b -> Maple c
mapleFun2 fn (Maple x) (Maple y) =
  Maple (liftM2 (\w z -> fn ++ "(" ++ w ++ ", " ++ z ++ ")") x y)

mapleOp2 :: String -> Maple a -> Maple b -> Maple c
mapleOp2 fn (Maple x) (Maple y) =
  Maple (liftM2 (\w z -> "(" ++ w ++ fn ++ z ++ ")") x y)

mapleBind :: (Maple a -> Maple b) -> Int -> (String, String)
mapleBind f i = (x, runMaple (f (Maple (return x))) (i + 1))
  where x = "x" ++ show i

instance Order Maple a where
  less = mapleOp2 "<"

instance Num (Maple a) where
  (+)              = mapleOp2 "+"
  (*)              = mapleOp2 "*"
  (-)              = mapleOp2 "-"
  negate (Maple x) = Maple (fmap (\u -> "(-" ++ u ++ ")") x)
  abs              = mapleFun1 "abs"
  signum           = mapleFun1 "signum"
  fromInteger x    = Maple (return (show x))

instance Fractional (Maple a) where
  (/)            = mapleOp2 "/"
  fromRational x = Maple (return ("(" ++ show (numerator   x) ++
                                  "/" ++ show (denominator x) ++ ")"))

instance Floating (Maple a) where
  pi    = Maple (return "Pi")
  exp   = mapleFun1 "exp"
  sqrt  = mapleFun1 "sqrt"
  log   = mapleFun1 "log"
  (**)  = mapleOp2 "^"
  logBase (Maple b) (Maple y) =
    Maple (liftM2 (\b' y' -> "log[" ++ b' ++ "]" ++ "(" ++ y' ++ ")") b y)
  sin   = mapleFun1 "sin"
  tan   = mapleFun1 "tan"
  cos   = mapleFun1 "cos"
  asin  = mapleFun1 "asin"
  atan  = mapleFun1 "atan"
  acos  = mapleFun1 "acos"
  sinh  = mapleFun1 "sinh"
  tanh  = mapleFun1 "tanh"
  cosh  = mapleFun1 "cosh"
  asinh = mapleFun1 "asinh"
  atanh = mapleFun1 "atanh"
  acosh = mapleFun1 "acosh"

instance Base Maple where
  unit = Maple (return "Unit")
  pair = mapleFun2 "Pair"
  unpair (Maple ab) k = Maple (ab >>= \ab' ->
    let opab :: Int -> String
        opab n = "op(" ++ show n ++ ", " ++ ab' ++ ")" 
    in
    unMaple (k (Maple (return (opab 1))) (Maple (return (opab 2)))))
  inl (Maple a) = x
    where x = case (typeOf x, typeOf1 x, typeOf2 x) of
              (Sum, One, One) -> Maple (return "true")
              _ -> Maple (fmap (\a' -> "Left("  ++ a' ++ ")") a)
  inr (Maple b) = x
    where x = case (typeOf x, typeOf1 x, typeOf2 x) of
              (Sum, One, One) -> Maple (return "false")
              _ -> Maple (fmap (\b' -> "Right(" ++ b' ++ ")") b)
  uneither x@(Maple ab) ka kb = Maple (ab >>= \ab' ->
    ReaderT $ \i -> cont $ \c ->
    case (typeOf x, typeOf1 x, typeOf2 x) of
    (Sum, One, One) -> let arm k = runCont (runReaderT (unMaple (k unit)) i) c
                       in "piecewise(" ++ ab' ++ ", " ++ arm ka
                                              ++ ", " ++ arm kb ++ ")"
    _ -> let opab :: Int -> String
             opab n = "op(" ++ show n ++ ", " ++ ab' ++ ")" in
         let arm tag k = opab 0 ++ " = " ++ tag ++ ", " ++
                         runCont (runReaderT (k (return (opab 1))) i) c in
         "piecewise(" ++ arm "Left"  (unMaple . ka . Maple)
              ++ ", " ++ arm "Right" (unMaple . kb . Maple) ++ ")")
  unsafeProb (Maple x) = Maple x
  fromProb   (Maple x) = Maple x
  sqrt_ = mapleFun1 "sqrt"
  pow_ = mapleOp2 "^"
  betaFunc = mapleFun2 "Beta"
  fix = mapleFun1 "(proc (f) local x; x := f(x) end proc)" . lam

instance Integrate Maple where
  integrate (Maple lo) (Maple hi) f = Maple (lo >>= \lo' -> hi >>= \hi' ->
    ReaderT $ \i -> return $
    let (x, body) = mapleBind f i
    in "int(" ++ body ++ "," ++ x ++ "=" ++ lo' ++ ".." ++ hi' ++ ")")
  infinity         = Maple (return  "infinity")
  negativeInfinity = Maple (return "-infinity")

instance Lambda Maple where
  lam f = Maple (ReaderT $ \i -> return $
    let (x, body) = mapleBind f i in "(" ++ x ++ "->" ++ body ++ ")")
  app (Maple rator) (Maple rand) =
    Maple (liftM2 (\rator' rand' -> rator' ++ "(" ++ rand' ++ ")") rator rand)

-- and now for the other way around: take things that came from Maple
-- (as strings), and interpret in Haskell.  This is probably not the best
-- place for this code, since Maple is supposed to produce proper Haskell,
-- but this is a start.
ourContext :: MonadInterpreter m => m ()
ourContext = do
  let modules = ["Language.Hakaru.Syntax", "Language.Hakaru.Maple"]
  loadModules modules
  setImports ("Prelude" : modules)

-- This is silly, as all we can read back in right now are fractions.
-- But at least this much works!
closeLoop :: (Typeable1 repr) => String -> IO (Either InterpreterError (repr ()))
closeLoop s = runInterpreter (ourContext >> interpret s undefined)

newtype Any a = Any
  { unAny :: forall repr. (Base repr, Lambda repr) => repr a }
deriving instance Typeable1 Any
  -- beware GHC 7.8 https://ghc.haskell.org/trac/ghc/wiki/GhcKinds/PolyTypeable

main :: IO () -- should print "(lam $ \x0 -> x0) `app` unit"
main = do
  result <- closeLoop "Any (lam id `app` unit)"
  case result of
    Left err -> print err
    Right a -> do
      print (runPrettyPrint (unAny a))
      putStrLn (runMaple (unAny a) 0)
