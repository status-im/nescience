import stint, strformat, strutils
import bncurve as bn256
import types

# TODO need a better converter
converter toBigInt*(constant:Constant):BigInt = i256(constant)
converter toBigInt*(sequence:seq[Constant]):seq[Int256] =
    sequence.map(proc (x: Constant): Int256 = x.toBigInt)

const
    # The ONE wire is a dedicated signal for generating 1 in the circuit
    ONE* = 1.toBigInt
    TWO* = 2.toBigInt
    ONE_WIRE* = "ONE_WIRE"


# Int256 / bn256 compatability

proc setZero*(value: var Int256) = value = 0.i256

proc one*(t: typedesc[Int256]): Int256 {.noinit, inline.} = 1.i256

proc fromString*(t: typedesc[Int256], value: string): Int256 = value.i256

# Equality

# proc `==`*[T](a: Wire; b: Wire): bool =

proc `==`*[T](a, b: Expression[T]): bool =
    if a.kind == b.kind:
        case a.kind
        of SingleTerm:
            return a.term == b.term
        of Quadratic:
            return a.leftTerms == b.leftTerms and a.rightTerms == b.rightTerms
        of Linear:
            return a.terms == b.terms
        of Boolean:
            return a.booleanWire == b.booleanWire
        of XOR:
            return a.a == b.a and a.b == b.b
        of Pack, Unpack:
            return a.bits == b.bits and a.res == b.res
        of Select:
            return a.sb == b.sb and a.x == b.x and a.y == b.y
        of Lookup:
            return a.b0 == b.b0 and a.b1 == b.b1 and a.table == b.table
        of Const:
            return a.v == b.v

proc `==`*[T](a, b: Constraint[T]): bool =
    return a.id == b.id and a.expressions == b.expressions and a.outputWire == b.outputWire

# toString

func `$`*(wire: Wire) : string =
    result = (&"(wire_{wire.name}_{wire.id})")
    result.add(&" (c {wire.constraintID})")
        

func `$`*[T](term: Term[T]) : string =
    &"{term.coefficient}{term.wire}"

func `$`*[T](terms: seq[Term[T]]) : string =
    terms.join(" + ")

func `$`*[T](expression: Expression[T]) : string =
    case expression.kind:
    of SingleTerm:
        if expression.operation == MUL:
            result = &"{expression.term}"
        else: # DIV
            result = &"({expression.term})^-1"
    of Quadratic:
        if expression.operation == MUL:
            result = &"({expression.leftTerms}) x ({expression.rightTerms})"
        else: # DIV
            result = &"({expression.leftTerms} x {expression.rightTerms})^-1"
    of Linear:
        result = $expression.terms
    of Boolean:
        result = &"(1-{expression.booleanWire}) x ({expression.booleanWire}) = 0"
    of XOR:
        result = &"{expression.a} + {expression.b}-2 x {expression.a} x {expression.b}"
    of Pack:
        # var bitString = @[]
        # for i, bit in expression.bits:
        #     bitString.add(&"{bit} x 2^{i}")
        result = "TODO Pack" #&"{bitString.join(" + ")}"
    of Unpack:
        # var bitString = @[]
        # for i, bit in expression.bits:
        #     bitString.add(&"{bit} x 2^{i}")
        result = "TODO Unpack" #&"{bitString.join(" + ")} = {expression.res}"
    of Select:
        # TODO confirm this is the case
        result = &"{expression.y} - {expression.sb} x ({expression.y} - {expression.x})"
    of Lookup:
         result = "TODO Lookup"
    of Const:
        result = &"{expression.v}"

    # result = "{" & result & "}"

func `$`*[T](expressions: seq[Expression[T]]) : string =
    expressions.join(", ")

func `$`*[T](constraint: Constraint[T]) : string =
    &"{constraint.expressions} = {constraint.outputWire}"

func `$`*[T](circuit: Circuit[T]) : string =
    result = "Single Output Constraints\n------\n"

    for i, constraint in circuit.singleOutputs:
        result.add(&"{constraint}\n")

    # TODO MOConstraint, NOConstraints


func `$`*[T](term: R1Term[T]): string =
    # TODO term.coefficient when field element does not return
    &"{term.coefficient}*:{term.id}"

func `$`*[T](terms: seq[R1Term[T]]): string =
    terms.join(" + ")
    
func `$`*[T](constraint: R1Constraint[T]): string =
    &"({constraint.L}) x ({constraint.R}) = ({constraint.O})"

func `$`*[T](constraints: seq[R1Constraint[T]]): string =
    result = "R1CS:\n"
    for i in constraints:
        result.add(&"{i}\n")

proc `/`*(x, y: bn256.FR): bn256.FR {.noinit, inline.} =
    # TODO this is wrong, likely the issue with constraint assertion
    let yInv = y.inverse().get()
    result = x * yInv