import stint, tables, bncurve as bn256

type
    BigInt* = Int256 | UInt256
    Constant* = SomeInteger | string | BigInt | bn256.FR

    # Enums

    InputKind* {.pure.} = enum
        Private, Public

    ExpressionKind* {.pure.} = enum
        SingleTerm, Linear, Quadratic, Boolean, XOR, Pack, Unpack, Select, Lookup, Const#, Imply

    Operation* {.pure.} = enum
        ADD = "+",
        SUB = "-",
        MUL = "*",
        DIV = "/"

    Solver* = enum
        SingleOutput, BinaryDecomposition

    # Wire

    Wire* = ref object
        name*: string
        id*: int64
        constraintID*: int64
        private*: bool
        consumed*: bool

    # Terms

    Term*[T] = ref object
        wire*: Wire
        coefficient*: T # Int256 | bn256.FR

    R1Term*[T] = object
        id*: int64
        coefficient*: T # Int256 | bn256.FR

    # Expressions
    # Relevant Procs to Expressions are:
        # `$` in utils.nim
        # replaceWire, consumeWires in circuit.nim
        # toR1CS in r1cs.nim

    Expression*[T] = object
        operation*: Operation # Used by SingleTerm and Quadratic
        case kind*: ExpressionKind
        of SingleTerm:
            term*: Term[T]
        of Linear:
            terms*: seq[Term[T]]
        of Quadratic:
            leftTerms*: seq[Term[T]]
            rightTerms*: seq[Term[T]]
        of Boolean:
            booleanWire*: Wire
        of XOR:
            a*: Wire
            b*: Wire
        of Pack, Unpack:
            ## (Un)pack a variable in binary
            ## bits[i]*2^i = res
            bits*: seq[Wire]
            res*: Wire
        of Select:
            ## Used to select a value according to a boolean evaluation
            ## b(y-x)=(y-z)
            sb*: Wire
            x*: Wire
            y*: Wire
        of Const:
            v*: Int256 # TODO should be a BigInt
        # # of Imply:
        # #     a,b: Wire
        of Lookup:
            b0*: Wire
            b1*: Wire
            table*: array[4, Int256] # TODO should be a BigInt

    # Constraints

    Constraint*[T] = object
        circuit*: Circuit[T]
        expressions*: seq[Expression[T]]
        outputWire*: Wire
        id*: int64

    R1Constraint*[T] = object
        L*: seq[R1Term[T]]
        R*: seq[R1Term[T]]
        O*: seq[R1Term[T]]
        solver*: Solver
    
    # Circuits

    Circuit*[T] = ref object
        singleOutputs*: Table[int64, Constraint[T]]
        multiOutputs*: seq[Expression[T]]
        zeroOutputs*: seq[Expression[T]]

    R1CS*[T] = object 
        numberOfWires*: int64
        numberOfPrivateWires*: int64
        numberOfPublicWires*: int64
        privateWires*: seq[string]
        publicWires*: seq[string]
        numberOfConstraints*: int64
        numberOfCOConstraints*: int64 # number of constraints that need to be solved, the first of the Constraints slice
        constraints*: seq[R1Constraint[T]]

    # Solution

    Input* = object
        kind*: InputKind # Private | Public
        value*: Int256 # TODO should be a "BigInt" type
    Solution* = Table["string", Input]