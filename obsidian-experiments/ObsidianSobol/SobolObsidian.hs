{-# LANGUAGE FlexibleContexts #-}
module SobolObsidianDyn where

import Obsidian
import Obsidian.CodeGen.CUDA (genKernel)

import Data.Word (Word32)
import Data.Bits hiding (testBit, bit)
import Prelude hiding (zipWith)

---------------------------------------------------
-- Helpers, should perhaps be included in Obsidian?
---------------------------------------------------

fromBool :: EBool -> EWord32
fromBool j = ifThenElse (j ==* Literal False) 0 1

bit :: EWord32 -> EWord32
bit i = 1 <<* i

testBit :: EWord32 -> EWord32 -> EBool
testBit x i = (x .&. bit i) ==* 0


---------------------------------
-- Parameters
---------------------------------
sobol_bit_count :: ASize s => s
sobol_bit_count = 30
sobol_dim :: ASize s => s
sobol_dim = 2
sobol_divisor :: EFloat
sobol_divisor = fromIntegral (2^30)

-- Direction vector 
-- TODO: Should be loaded from file (2D array of size 2*30)
sobol_dirVs :: DPull EWord32
sobol_dirVs = undefinedGlobal (30 * Literal sobol_dim)

sobol_dirVsND :: ASize s => Pull s (Pull s Word32)
sobol_dirVsND = splitUp sobol_bit_count (undefinedGlobal (30 * sobol_dim))

-- ---------------------------------
-- -- Sobol independent
-- ---------------------------------

grayCode :: (ASize s, Bits s) => s -> s
grayCode ix = ix `xor` (ix `shiftR` 1)

-- Computes a singleton array containing the sobol-number
-- at index 'ix' (inherently sequential)
-- Uses the independent formula
--sobolInd :: EWord32 -> DPull EWord32 -> DPush Thread EWord32
sobolInd ix dirVs = execThread' $ seqReduce xor $ zipWith (*) dirVs bitVec
  where
   bitVec :: DPull EWord32
   bitVec = mkPull sobol_bit_count (\i -> fromBool $ testBit (grayCode ix) i)

sobolIndReal :: EWord32 -> DPull EWord32 -> SPush Thread EFloat
sobolIndReal i dirVs = fmap normalise $ sobolInd i dirVs
  where
   normalise x = w32ToF x / sobol_divisor

blockSize = 512

-- Compute 1D sobol sequence
sobol1D :: Word32 -> DPull EWord32 -> SPush Grid EFloat
sobol1D n dirVs = asGrid  $ mkPull gridSize
                    (\bid -> asBlock $ mkPull blockSize
                      (\tid -> sobolIndReal (bid * (Literal blockSize) + tid) dirVs))
  where
    gridSize = (n+blockSize) `div` blockSize

sobol_iterations = 10000
sobol1DKernel = putStrLn $ genKernel blockSize "sobol1D" (sobol1D sobol_iterations)

sobolND :: Word32 -> Word32 -> DPull EWord32 -> SPush Grid EFloat
sobolND dim n dirV =
  asGrid $ mkPull n (\i -> asBlock $ fmap (sobolIndReal i) dirVs)
  where
   dirVs :: SPull (DPull EWord32)
   dirVs = fromDyn dim (splitUp sobol_bit_count dirV)

sobolNDKernel = putStrLn $ genKernel blockSize "sobolND" (sobolND sobol_iterations sobol_dim)