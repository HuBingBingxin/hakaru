{-# LANGUAGE DataKinds,
             FlexibleContexts,
             GADTs #-}

module HKC.Flatten where

import Language.Hakaru.Syntax.AST
import Language.Hakaru.Syntax.ABT

import Language.C.Data.Node
import Language.C.Data.Position
import Language.C.Syntax.AST

flatten :: ABT Term abt => abt xs a -> CTranslUnit
flatten e =
  let n = undefNode in
  case viewABT e of
    _           -> CTranslUnit [CDeclExt (CDecl [CTypeSpec (CIntType n)] [] n)] n
    -- (Syn t)    -> CTranslUnit [] undefNode
    -- (Var x)    -> CTranslUnit [] undefNode
    -- (Bind x v) -> CTranslUnit [] undefNode

-- flatten' :: ABT Term abt => abt '[] a -> CTranslUnit
-- flatten' = cataABT var bind alg

--    void main(){ srand(time(NULL)); while(1) { printf("%.17g\n" ,p ,r);}