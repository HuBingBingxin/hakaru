{-# LANGUAGE RankNTypes, DataKinds, NoMonomorphismRestriction, BangPatterns #-}

module Examples where

import Language.Hakaru.Types
import Data.Dynamic
import Control.Monad

import Language.Hakaru.ImportanceSampler
import Language.Hakaru.Distribution
import Language.Hakaru.Lambda
import Language.Hakaru.Util.Visual

bayesian_polynomial_regression = undefined

sparse_linear_regression = undefined

logistic_regression = undefined

outlier_detection = undefined

change_point_model = undefined

friends_who_smoke = undefined

latent_dirichelt_allocation = undefined

categorical_mixture = undefined

nPoints :: Int
nPoints = 6

gaussianMixture :: Measure [Double]
gaussianMixture = do
  p <- unconditioned (beta 2 2)
  [m1,m2] <- replicateM 2 $ unconditioned (normal 100 30)
  [s1,s2] <- replicateM 2 $ unconditioned (uniform 0 2)
  let makePoint = do        
        b <- unconditioned (bern p)
        unconditioned (ifThenElse b (normal m1 s1)
                                    (normal m2 s2))
  replicateM nPoints makePoint

testGaussianMixture :: IO ()
testGaussianMixture = 
    sample gaussianMixture [] >>= viz nPoints ["x"] . convert . take 1
    where convert [(xs,_)] = [[x] | x <- xs]

naive_bayes = undefined

hidden_markov_model = undefined

matrix_factorization = undefined

type Point = [Double] -- datapoint type

-- TODO: Rewrite using sparse matrix operations
kernel :: Point -> Point -> Double
kernel x x' = exp $ (* (-0.5)) $ sum $ map (\ (x,x') -> (x - x')*(x - x')) $ zip x x'

-- TODO: Rewrite using sparse matrix operations
predict :: [Double] -> Point -> [Point] -> Double
predict w x train = sum $ map (\ (w_i, x_i) -> w_i * (kernel x x_i)) $ zip w train

rvm x = do
  a <- replicateM 20 $ unconditioned (gamma 1e-4 1e-4)
  sigma <- unconditioned (gamma 1e-4 1e-4)
  w <- mapM (\ a -> unconditioned (normal 0 (recip a))) a
  y <- mapM (\x_i -> conditioned $ normal (predict w x_i x) sigma) x
  return w

item_response_theory = undefined

gaussian_process = undefined

hawkes_process = undefined

bayesian_neural_network = undefined
