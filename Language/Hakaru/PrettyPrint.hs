{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, GADTs, ScopedTypeVariables, TypeFamilies, DataKinds #-}
{-# OPTIONS -Wall -Werror #-}
module Language.Hakaru.PrettyPrint (PrettyPrint,
  runPrettyPrint, runPrettyPrintPrec, runPrettyPrintNamesPrec, leftMode) where

-- Pretty-printing interpretation

import Language.Hakaru.Syntax
import Language.Hakaru.Util.Pretty
import Text.PrettyPrint hiding (parens, empty)
import Language.Hakaru.Embed
import Data.List ((\\))

leftMode :: Doc -> String
leftMode = renderStyle style{mode=LeftMode}

newtype PrettyPrint (a :: Hakaru *) = PP ([String] -> Int -> [Doc])

runPrettyPrint :: PrettyPrint a -> Doc
runPrettyPrint pp = runPrettyPrintPrec pp 0

runPrettyPrintPrec :: PrettyPrint a -> Int -> Doc
runPrettyPrintPrec (PP a) p = sep (a defaultNames p)

runPrettyPrintNamesPrec :: PrettyPrint a -> [String] -> Int -> Doc
runPrettyPrintNamesPrec (PP a) customNames p =
  sep $ drop (length customNames)
      $ a (customNames ++ (defaultNames \\ customNames)) p

defaultNames :: [String]
defaultNames = [ 'x' : show i | i <- [0::Int ..] ]

instance Show (PrettyPrint a) where
  show        = show        . pretty
  showsPrec p = showsPrec p . (`runPrettyPrintPrec` p)
  showList    = showsPrec 0 . pretty

instance Pretty (PrettyPrint a) where
  pretty = runPrettyPrint

apply1 :: String -> PrettyPrint a -> PrettyPrint b
apply2 :: String -> PrettyPrint a -> PrettyPrint b -> PrettyPrint c
apply3 :: String -> PrettyPrint a -> PrettyPrint b -> PrettyPrint c ->
          PrettyPrint d

apply1 f (PP a) =
  PP (\xs p -> [prettyFun (p > 10) f (sep (a xs 11))])
apply2 f (PP a) (PP b) =
  PP (\xs p -> [prettyFun (p > 10) f (sep [sep (d xs 11) | d <- [a,b]])])
apply3 f (PP a) (PP b) (PP c) =
  PP (\xs p -> [prettyFun (p > 10) f (sep [sep (d xs 11) | d <- [a,b,c]])])

applyPairs :: String -> [(PrettyPrint a, PrettyPrint b)] -> PrettyPrint c
applyPairs s pms = apply1 s (PP (\xs _ ->
                    [brackets (nest 1 (sep (punctuate comma
                       [ prettyPair (sep (p xs 0)) (sep (m xs 0))
                       | (PP p, PP m) <- pms ])))]))

adjustHead :: (Doc -> Doc) -> [Doc] -> [Doc]
adjustHead f []     = [f (sep [])]
adjustHead f (d:ds) = f d : ds

parens :: Bool -> [Doc] -> [Doc]
parens True  ds = [char '(' <> nest 1 (sep ds) <> char ')']
parens False ds = ds

fun1 :: (PrettyPrint a -> PrettyPrint b) -> PrettyPrint ('HFun a b)
fun1 f = PP (\(x:xs) p ->
  let PP b = f (PP (\_ _ -> [text x])) in
  parens (p > 10) (text ('\\' : x ++ " ->") : b xs 0))

fun2 :: (PrettyPrint a -> PrettyPrint b -> PrettyPrint c) ->
        PrettyPrint ('HFun a ('HFun b c))
fun2 f = PP (\(x:x':xs) p ->
  let PP b = f (PP (\_ _ -> [text x])) (PP (\_ _ -> [text x'])) in
  parens (p > 10) (text ('\\' : x ++ ' ' : x' ++ " ->") : b xs 0))

instance (Number a) => Order PrettyPrint a where
  less  = op 4 "`less`"  5 5
  equal = op 4 "`equal`" 5 5

instance Num (PrettyPrint a) where
  (+)           = op 6 "+" 6 7
  (*)           = op 7 "*" 7 8
  (-)           = op 6 "-" 6 7
  negate (PP b) = PP (\xs p -> [prettyParen (p > 6) (char '-' <> sep (b xs 7))])
  abs           = apply1 "abs"
  signum        = apply1 "signum"
  fromInteger n = PP (\_ _ -> [integer n])

instance Fractional (PrettyPrint a) where
  (/)            = op 7 "/" 7 8
  recip          = apply1 "recip"
  fromRational n = PP (\_ p -> [text (showRatio p n "")])

instance Floating (PrettyPrint a) where
  pi      = string "pi"
  exp     = apply1 "exp"
  sqrt    = apply1 "sqrt"
  log     = apply1 "log"
  (**)    = op 8 "**" 9 8
  logBase = apply2 "logBase"
  sin     = apply1 "sin"
  cos     = apply1 "cos"
  tan     = apply1 "tan"
  asin    = apply1 "asin"
  acos    = apply1 "acos"
  atan    = apply1 "atan"
  sinh    = apply1 "sinh"
  cosh    = apply1 "cosh"
  tanh    = apply1 "tanh"
  asinh   = apply1 "asinh"
  atanh   = apply1 "atanh"
  acosh   = apply1 "acosh"

instance Base PrettyPrint where
  unit              = string "unit"
  pair              = apply2 "pair"
  unpair (PP xy) k  = let PP k' = fun2 k in PP (\xs p -> parens (p > 0)
                    $ adjustHead (sep (xy xs 9) <+> text "`unpair`" <+>)
                    $ k' xs 10)
  inl               = apply1 "inl"
  inr               = apply1 "inr"
  uneither xy kx ky = apply3 "uneither" xy (fun1 kx) (fun1 ky)
  true              = string "true"
  false             = string "false"
  if_               = apply3 "if_"
  unsafeProb        = apply1 "unsafeProb"
  fromProb          = apply1 "fromProb"
  fromInt           = apply1 "fromInt"
  pi_               = string "pi_"
  exp_              = apply1 "exp_"
  erf               = apply1 "erf"
  erf_              = apply1 "erf_"
  log_              = apply1 "log_"
  sqrt_             = apply1 "sqrt_"
  pow_              = apply2 "pow_"
  infinity          = string "infinity"
  negativeInfinity  = string "negativeInfinity"
  gammaFunc         = apply1 "gammaFunc"
  betaFunc          = apply2 "betaFunc"
  vector l f        = apply2 "vector" l (fun1 f)
  empty             = string "empty"
  index             = apply2 "index"
  size              = apply1 "size"
  reduce f          = apply3 "reduce" (fun2 f)
  fix f             = apply1 "fix" (fun1 f)

instance Mochastic PrettyPrint where
  dirac         = apply1 "dirac"
  bind (PP m) k = let PP k' = fun1 k in PP (\xs p -> parens (p > 0)
                $ adjustHead (sep (m xs 1) <+> text "`bind`" <+>)
                $ k' xs 2)
  lebesgue      = string "lebesgue"
  counting      = string "counting"
  superpose [(PP pp, PP m)] = PP (\xs p -> parens (p > 0)
                                         $ text "weight" <+> sep (pp xs 11)
                                                         <+> char '$'
                                         : m xs 0)
  superpose pms = applyPairs "superpose" pms
  uniform       = apply2 "uniform"
  normal        = apply2 "normal"
  categorical   = apply1 "categorical"
  poisson       = apply1 "poisson"
  gamma         = apply2 "gamma"
  beta          = apply2 "beta"
  dp            = apply2 "dp"
  chain         = apply1 "chain"
  plate         = apply1 "plate"

instance Integrate PrettyPrint where
  integrate a b f = apply3 "integrate" a b (fun1 f)
  summate   a b f = apply3 "summate"   a b (fun1 f)

instance Lambda PrettyPrint where
  lam f         = let PP f' = fun1 f in
                  PP (\xs p -> parens (p > 0)
                             $ adjustHead (text "lam $" <+>)
                             $ f' xs 0)
  app           = op 9 "`app`" 9 10
  let_ (PP a) f = let PP f' = fun1 f in
                  PP (\xs p -> parens (p > 0)
                             $ adjustHead (text "let_" <+> sep (a xs 11)
                                                       <+> char '$' <+>)
                             $ f' xs 0)

op :: Int -> String -> Int -> Int ->
      PrettyPrint a -> PrettyPrint b -> PrettyPrint c
op p0 s p1 p2 (PP a) (PP b) =
  PP (\xs p -> [prettyOp (p > p0) s (sep (a xs p1)) (sep (b xs p2))])

string :: String -> PrettyPrint a
string s = PP $ \_ _ -> [text s] 

instance Embed PrettyPrint where 
  _Nil = string "_Nil"
  _Cons = apply2 "_Cons" 
  _Z = apply1 "_Z" 
  _S = apply1 "_S" 
  caseProd x f = apply2 "caseProd" x (lam2 f) 
  caseSum x f g = apply3 "caseSum" x (lam f) (lam g) 
  tag = apply1 "tag"
  untag = apply1 "untag" 
