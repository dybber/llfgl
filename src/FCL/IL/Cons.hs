-- | Untyped constructors for building CGen-kernels
module FCL.IL.Cons (
  
 -- Expressions
 let_, letVar, index, (!), if_,
 -- Getter's (launch parameters and current thread info)
 var, string, int, bool, double,

 -- -- Unary operators
 -- not, i2d, negatei, negated,
 absi, absd, signi, b2i,
 -- negateBitwise,
 -- ceil, floor, exp, ln,
 -- addressOf, deref, sizeOf,
 clz,
 
 -- Binary operators
 addi, subi, muli, divi, modi,
 -- addd, subd, muld, divd,
 -- addPtr,
 lti, ltei, gti, gtei, eqi, neqi,
 ltd, lted, gtd, gted, eqd, neqd,
 land, lor, xor,
 sll, srl,
 -- (&&*), (||*),
 mini, maxi,
 
 -- Statements
 allocate,
 distribute, parFor, seqFor, while, iff,
 assign, (<==), assignArray,
 printIntArray, readIntCSV, benchmark,

 -- Monad
 ILName,
 Program,
 ILExp,
 ILType(..),
 ILLevel(..)
)
where

import Prelude hiding (not, floor, exp)
--import Data.Word (Word32, Word8)

import FCL.IL.Syntax as AST
import FCL.IL.Program

----------------------
-- Variable binding --
----------------------

-- Variable binder. Creates a fresh variable, adds a declaration
-- w. initialiser and passes it on
let_ :: String -> ILType -> ILExp -> Program ILExp
let_ name ty e = do
  v <- newVar name
  addStmt (Declare v ty e ())
  return (EVar v)

letVar :: String -> ILType -> ILExp -> Program ILName
letVar name ty e = do
  v <- newVar name
  addStmt (Declare v ty e ())
  return v

var :: ILName -> ILExp
var v = EVar v

----------------
-- Statements --
----------------

allocate :: ILType -> ILExp -> Program ILName
allocate elemty n =
  do arr <- newVar "arr"
     addStmt (Alloc arr elemty n ())
     return arr

-- I think these two are wrong, we should not just start with an
-- initial state, the varCount at least has to be passed on.

-- construct a for loop, where the body is generated by a function
-- taking the index variable as parameter
distribute :: ILLevel -> ILExp -> (ILExp -> Program ()) -> Program ()
distribute lvl ub f = do
  i <- newVar "i"
  let_ "ub" ILInt ub >>= (\upperbound -> do
    body <- run (f (EVar i))
                               -- TODO: Var count should be passed on!
    addStmt (Distribute lvl i upperbound body ()))

parFor :: ILLevel -> ILExp -> (ILExp -> Program ()) -> Program ()
parFor lvl ub f = do
  i <- newVar "i"
  let_ "ub" ILInt ub >>= (\upperbound -> do
    body <- run (f (EVar i))
                               -- TODO: Var count should be passed on!
    addStmt (ParFor lvl i upperbound body ()))

seqFor :: ILExp -> (ILExp -> Program ()) -> Program ()
seqFor ub f = do
  i <- newVar "i"
  let_ "ub" ILInt ub >>= (\upperbound -> do
    body <- run (f (EVar i))
                               -- TODO: Var count should be passed on!
    addStmt (SeqFor i upperbound body ()))


-- whileLoop :: CExp -> CGen u () -> CGen u ()
-- whileLoop f body = whileUnroll 0 f body

while :: ILExp -> Program () -> Program ()
while cond body = do
  body' <- run body -- TODO: Var count should be passed on!
  addStmt (While cond body' ())
                                    
iff :: ILExp -> (Program (), Program ()) -> Program ()
iff cond (f1, f2) = do
  f1' <- run f1
  f2' <- run f2
  addStmt (If cond f1' f2' ())

-- assign variable, and add to current list of operators
assign :: ILName -> ILExp -> Program ()
assign name e = addStmt (Assign name e ())

(<==) :: ILName -> ILExp -> Program ()
name <== e = assign name e

-- assign to an array
assignArray :: ILName -> ILExp -> ILExp -> Program ()
assignArray arrILName e idx = addStmt (AssignSub arrILName idx e ())

printIntArray :: ILExp -> ILExp -> Program ()
printIntArray prefix arr = addStmt (PrintIntArray prefix arr ())

readIntCSV :: ILExp -> Program (ILName, ILExp)
readIntCSV file =
  do arr <- newVar "arr"
     len <- newVar "len"
     addStmt (ReadIntCSV arr len file ())
     return (arr, var len)

benchmark :: ILExp -> Program () -> Program ()
benchmark iterations prog =
  do p' <- run prog
     addStmt (Benchmark iterations p' ())

-----------------
-- Expressions --
-----------------

string :: String -> ILExp
string = EString

int :: Int -> ILExp
int = EInt

double :: Double -> ILExp
double = EDouble

bool :: Bool -> ILExp
bool = EBool

if_ :: ILExp -> ILExp -> ILExp -> ILExp
if_ econd etrue efalse = EIf econd etrue efalse

-- (?) :: CExp -> (CExp, CExp) -> CExp
-- econd ? (e0,e1) = if_ econd e0 e1

index :: ILName -> ILExp -> ILExp
index arrILName e = EIndex arrILName e

(!) :: ILName -> ILExp -> ILExp
(!) = index

-----------------
--  Operators  --
-----------------

-- not :: ILExp -> ILExp
-- not = UnaryOpE Not

-- i2d :: ILExp -> ILExp
-- i2d e = UnaryOpE I2D e
-- negatei :: ILExp -> ILExp
-- negatei = UnaryOpE NegateInt
-- negated :: ILExp -> ILExp
-- negated = UnaryOpE NegateDouble
-- negateBitwise :: ILExp -> ILExp
-- negateBitwise = UnaryOpE NegateBitwise
-- ceil :: ILExp -> ILExp
-- ceil = UnaryOpE Ceil
-- floor :: ILExp -> ILExp
-- floor = UnaryOpE Floor
-- exp :: ILExp -> ILExp
-- exp = UnaryOpE Exp
-- ln :: ILExp -> ILExp
-- ln = UnaryOpE Ln
absi :: ILExp -> ILExp
absi = EUnaryOp AbsI
signi :: ILExp -> ILExp
signi = EUnaryOp SignI
absd :: ILExp -> ILExp
absd = EUnaryOp AbsD
clz :: ILExp -> ILExp
clz = EUnaryOp CLZ
b2i :: ILExp -> ILExp
b2i = EUnaryOp B2I

-- Arithmetic (Int)
addi, subi, muli, divi, modi :: ILExp -> ILExp -> ILExp
e0 `addi` e1 = (EBinOp AddI e0 e1)
e0 `subi` e1 = (EBinOp SubI e0 e1)
e0 `muli` e1 = (EBinOp MulI e0 e1)
e0 `divi` e1 = (EBinOp DivI e0 e1)
e0 `modi` e1 = (EBinOp ModI e0 e1)

-- -- Arithmetic (Double)
-- addd, subd, muld, divd :: ILExp -> ILExp -> ILExp
-- e0 `addd` e1 = (EBinOp AddD e0 e1)
-- e0 `subd` e1 = (EBinOp SubD e0 e1)
-- e0 `muld` e1 = (EBinOp MulD e0 e1)
-- e0 `divd` e1 = (EBinOp DivD e0 e1)

-- -- Comparisons (Int)
lti, ltei, gti, gtei, eqi, neqi :: ILExp -> ILExp -> ILExp
lti  e0 e1 = (EBinOp LtI e0 e1)
ltei e0 e1 = (EBinOp LteI e0 e1)
gti  e0 e1 = (EBinOp GtI e0 e1)
gtei e0 e1 = (EBinOp GteI e0 e1)
eqi  e0 e1 = (EBinOp EqI e0 e1)
neqi e0 e1 = (EBinOp NeqI e0 e1)

-- Comparisons (Double)
ltd, lted, gtd, gted, eqd, neqd  :: ILExp -> ILExp -> ILExp
ltd  e0 e1 = (EBinOp LtD e0 e1)
lted e0 e1 = (EBinOp LteD e0 e1)
gtd  e0 e1 = (EBinOp GtD e0 e1)
gted e0 e1 = (EBinOp GteD e0 e1)
eqd  e0 e1 = (EBinOp EqD e0 e1)
neqd e0 e1 = (EBinOp NeqD e0 e1)

-- Bitwise operations
land, lor, xor :: ILExp -> ILExp -> ILExp
land e0 e1 = (EBinOp Land e0 e1)
lor  e0 e1 = (EBinOp Lor e0 e1)
xor  e0 e1 = (EBinOp Xor e0 e1)

sll, srl :: ILExp -> ILExp -> ILExp
sll  e0 e1 = (EBinOp Sll e0 e1)
srl  e0 e1 = (EBinOp Srl e0 e1)

-- -- Boolean 'and' and 'or'
-- (&&*), (||*) :: ILExp -> ILExp -> ILExp
-- e0 &&* e1 = (EBinOp And e0 e1)
-- e0 ||* e1 = (EBinOp Or e0 e1)

mini, maxi :: ILExp -> ILExp -> ILExp
mini a b = EBinOp MinI a b
maxi a b = EBinOp MaxI a b

-- signi :: ILExp -> ILExp
-- signi a =
--   let -- instead of putting type annotations in everywhere
--       i :: Int -> CExp
--       i = constant
--   in if_ (a `eqi` i 0) (i 0) (if_ (a `lti` i 0) (i (-1)) (i 1))
