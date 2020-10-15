import stint, bitops
import bncurve as bn256

type
    Domain*[T] = object 
        generator*: T
        generatorInv*: T
        generatorSqrt*: T
        generatorSqrtInv*: T
        cardinality*: int
        cardinalityInv*: T

proc nextPowerOfTwo(m: uint64): uint64 {.inline.} =
    # TODO could probably just use math.nextPowerOfTwo ?
    if (m and m-1) == 0: return m
    result = 1
    while result < m:
        result = result shl 1

proc newDomain*[T](rootOfUnity: T, maxOrderRoot: uint, m: int64): Domain[T] =
    result = Domain[T]()
    let
        x = nextPowerOfTwo(m.uint64)
        logx = countTrailingZeroBits(x).uint
    
    assert logx <= maxOrderRoot,
        "m is too big, the required root of unity does not exist"

    # TODO theres got to be a better way to create a BNU256 from an expression?
    # let exponent = [uint64(1.uint shl maxOrderRoot - logx - 1.uint), 0'u64, 0'u64, 0'u64]
    let exponent = uint64(1.uint shl maxOrderRoot - logx - 1.uint)
    let hmm = stuint(rootOfUnity, 256).pow(exponent)
    # result.generatorSqrt = rootOfUnity.pow(exponent)
    # result.generator = result.generatorSqrt * result.generatorSqrt
    result.cardinality = x.int
    # result.generatorSqrtInv = result.generatorSqrt.inverse().get()
    # result.generatorInv = result.generator.inverse().get()
    # result.cardinalityInv = T.fromString($(result.cardinality)).inverse().get()
    # TODO this all seems hacky, at best.