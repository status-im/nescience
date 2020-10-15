import strformat, stint, tables, sequtils, algorithm

import circuit, types, utils

# https://raw.githubusercontent.com/zcash/zips/master/protocol/protocol.pdf
# https://z.cash/technology/jubjub/

proc input*[T](circuit: var Circuit[T], name: string, access: InputKind): Constraint[T] =
    ## Define inputs into the circuit, analagous to newConstraint
    assert not circuit.hasInput(name),
        &"The input {name} has already been defined"
    var constraint = Constraint[T](
        circuit: circuit,
        id: -1,
        outputWire: Wire(
            name: name,
            private: access == Private,
            consumed: true,
            constraintID: -1,
            id: -1
        )
    )
    circuit.addConstraint(constraint)
    return constraint

proc toConstraint*[T](circuit: var Circuit[T], constant: Constant): Constraint[T] =
    if constant == 1.i256:
        # TODO should oneWire just be an allocated constant expression?
        return circuit.oneConstraint

    let expression = Expression[T](kind: Const, v: constant.toBigInt)
    circuit.newConstraint(expression)

## Addition

proc add*[T](circuit: var Circuit[T], a, b: Constraint[T]): Constraint[T] =
    ## a * 1 + b * 1
    let expression = Expression[T](kind: Linear,
        terms:  @[
            Term[T](wire: a.outputWire, coefficient: ONE),
            Term[T](wire: b.outputWire, coefficient: ONE)
        ]
    )
    circuit.newConstraint(expression)

proc add*[T](circuit: var Circuit[T], constraint: Constraint[T], constant: Constant): Constraint[T] =
    ## constraint * 1 + constant * 1
    let expression = Expression[T](kind: Linear,
        terms: @[
            Term[T](wire: constraint.outputWire, coefficient: ONE),
            Term[T](wire: circuit.oneWire, coefficient: constant.toBigInt) # TODO BigInt
        ]
    )
    circuit.newConstraint(expression)

proc add*[T](circuit: var Circuit[T], constant: Constant, constraint: Constraint[T]): Constraint[T] =
    circuit.add(constraint, constant)

proc add*[T](circuit: var Circuit[T], a, b: Constraint[T] | Constant, args: varargs[Constraint[T] | Constant]): Constraint[T] =
    result = circuit.add(a, b)
    for i in 0..<args.len:
        result = circuit.add(result, args[i])

func `+`*[T](x, y: var Constraint[T]): Constraint[T] {.inline.} =
    assert x.circuit == y.circuit,
        "Constraints must belong to same circuit"
    x.circuit.add(x, y)

func `+`*[T](x: var Constraint[T], y: Constant): Constraint[T] {.inline.} =
    x.circuit.add(x, y)

func `+`*[T](x: Constant, y: var Constraint[T]): Constraint[T] {.inline.} =
    y.circuit.add(x, y)

## Subtraction

proc sub*[T](circuit: var Circuit[T], a, b: Constraint[T]): Constraint[T] =
    ## a * 1 + b * -1
    let expression = Expression[T](kind: Linear,
        terms: @[
            Term[T](wire: a.outputWire, coefficient: ONE),
            Term[T](wire: b.outputWire, coefficient: -ONE),
        ]
    )
    circuit.newConstraint(expression)

proc sub*[T](circuit: var Circuit[T], constraint: Constraint[T], constant: Constant): Constraint[T] =
    ## constraint * 1 + constant * -1
    let expression = Expression[T](kind: Linear,
        terms: @[
            Term[T](wire: constraint.outputWire, coefficient: ONE),
            Term[T](wire: circuit.oneWire, coefficient: -constant.toBigInt), # TODO BigInt
        ]
    )
    circuit.newConstraint(expression)

proc sub*[T](circuit: var Circuit[T], constant: Constant, constraint: Constraint[T]): Constraint[T] =
    # Subtraction is not Commutative
    let expression = Expression[T](kind: Linear,
        terms: @[
            Term[T](wire: circuit.oneWire, coefficient: constant.toBigInt), # TODO BigInt
            Term[T](wire: constraint.outputWire, coefficient: -ONE),
        ]
    )
    circuit.newConstraint(expression)

# TODO should this be supported?
proc sub*[T](circuit: var Circuit, a, b: Constraint[T] | Constant, args: varargs[Constraint[T] | Constant]): Constraint[T] =
    result = circuit.sub(a, b)
    for i in 0..<args.len:
        result = circuit.sub(result, args[i])


func `-`*[T](x, y: var Constraint[T]): Constraint[T] {.inline.} =
    assert x.circuit == y.circuit,
        "Constraints must belong to same circuit"
    x.circuit.sub(x, y)

func `-`*[T](x: var Constraint[T], y: Constant): Constraint[T] {.inline.} =
    x.circuit.sub(x, y)

func `-`*[T](x: Constant, y: var Constraint[T]): Constraint[T] {.inline.} =
    y.circuit.sub(x, y)

## Multiplication

proc mul*[T](circuit: var Circuit[T], a, b: Constraint[T]): Constraint[T] =
    ## left[a] * right[b]
    let expression = Expression[T](kind: Quadratic,
        operation: MUL,
        leftTerms: @[Term[T](wire: a.outputWire, coefficient: ONE)],
        rightTerms: @[Term[T](wire: b.outputWire, coefficient: ONE)]
    )
    circuit.newConstraint(expression)

proc mul*[T](circuit: var Circuit[T], constraint: Constraint[T], constant: Constant): Constraint[T] =
    ## constraint * constant
    let expression = Expression[T](kind: SingleTerm,
            operation: MUL,
            term: Term[T](wire: constraint.outputWire, coefficient: constant.toBigInt) # TODO BigInt
    )
    circuit.newConstraint(expression)

proc mul*[T](circuit: var Circuit[T], constant: Constant, constraint: Constraint[T]): Constraint[T] =
    circuit.mul(constraint, constant)

proc mul*[T](circuit: var Circuit[T], a, b: seq[Term[T]]): Constraint[T] =
    # TODO Quadratic Equation that multiplies terms
    assert false, "Not Implemented"

proc mul*[T](circuit: var Circuit[T], a, b: Constraint[T] | Constant, args: varargs[Constraint[T] | Constant]): Constraint[T] =
    result = circuit.mul(a, b)
    for i in 0..<args.len:
        result = circuit.mul(result, args[i])

func `*`*[T](x, y: var Constraint[T]): Constraint[T] {.inline.} =
    assert x.circuit == y.circuit,
        "Constraints must belong to same circuit"
    x.circuit.mul(x, y)

func `*`*[T](x: var Constraint[T], y: Constant): Constraint[T] {.inline.} =
    x.circuit.mul(x, y)

func `*`*[T](x: Constant, y: var Constraint[T]): Constraint[T] {.inline.} =
    y.circuit.mul(x, y)

## Exponentiation

proc pow*[T](circuit: var Circuit[T], x: Constraint[T], y: SomeInteger): Constraint[T] =
    result = x
    for i in 0..<y-1:
        result = circuit.mul(result, x)

func `^`*[T](x: var Constraint[T], y: SomeInteger): Constraint[T] {.inline.} =
    x.circuit.pow(x, y)

## Division

proc `div`*[T](circuit: var Circuit[T], a, b: Constraint[T]): Constraint[T] =
    ## a / b
    ## rightTerms are the numerator, leftTerms are the denominator
    let expression = Expression[T](kind: Quadratic,
        operation: DIV,
        leftTerms: @[Term[T](wire: b.outputWire, coefficient: ONE)],
        rightTerms: @[Term[T](wire: a.outputWire, coefficient: ONE)]
    )
    circuit.newConstraint(expression)

proc `div`*[T](circuit: var Circuit[T], constraint: Constraint[T], constant: Constant): Constraint[T] =
    ## constraint / constant
    let expression = Expression[T](kind: Quadratic,
        operation: DIV,
        leftTerms: @[Term[T](wire: circuit.oneWire, coefficient: constant)],
        rightTerms: @[Term[T](wire: constraint.outputWire, coefficient: ONE)]
    )
    circuit.newConstraint(expression)

proc `div`*[T](circuit: var Circuit[T], constant: Constant, constraint: Constraint[T]): Constraint[T] =
    ## constant / constraint
    let expression = Expression[T](kind: Quadratic,
        operation: DIV,
        leftTerms: @[Term[T](wire: constraint.outputWire, coefficient: ONE)],
        rightTerms: @[Term[T](wire: circuit.oneWire, coefficient: constant)]
    )
    circuit.newConstraint(expression)

proc `div`*[T](circuit: var Circuit[T], a, b: seq[Term[T]]): Constraint[T] =
    # TODO Quadratic Equation that divides terms
    assert false, "Not Implemented"

func `/`*[T](x, y: var Constraint[T]): Constraint[T] {.inline.} =
    assert x.circuit == y.circuit,
        "Constraints must belong to same circuit"
    x.circuit.div(x, y)

func `/`*[T](x: var Constraint[T], y: Constant): Constraint[T] {.inline.} =
    x.circuit.div(x, y)

func `/`*[T](x: Constant, y: var Constraint[T]): Constraint[T] {.inline.} =
    y.circuit.div(x, y)

## Equality (Well, Assertions)

proc equal*[T](circuit: var Circuit[T], a, b: Constraint[T]) =
    ## a == b
    assert a != b,
        "A constraint cannot be compared against itself"

    assert not a.outputWire.isNil and not b.outputWire.isNil,
        "Missing outputWire for constraint"
    
    assert not (a.outputWire.isInput and b.outputWire.isInput),
        "Two user defined parameters cannot be compared"

    var (c1, c2) = if a.outputWire.isInput: (b, a) else: (a, b)
    
    # Concatenate the expressions of both constraints
    c1.expressions = concat(c1.expressions, c2.expressions)

    let wireToReplace = c1.outputWire

    # replace all occurences of c1's outputWire in all expressions with c2.outputWire
    c1.outputWire = c2.outputWire
    for i, constraint in pairs(circuit.singleOutputs):
        for expression in circuit.singleOutputs[i].expressions.mitems:
            expression.replaceWire(wireToReplace, c2.outputWire)
    
    for expression in circuit.multiOutputs.mitems:
        expression.replaceWire(wireToReplace, c2.outputWire)
    
    for expression in circuit.zeroOutputs.mitems:
        expression.replaceWire(wireToReplace, c2.outputWire)
    
    circuit.singleOutputs.del(c2.id)
    circuit.singleOutputs[c1.id] = c1

# proc equal*[T](circuit: var Circuit[T], constraint: Constraint[T], constant:Constant) =
#     assert not constraint.outputWire.isInput,
#         "Input == Constant is invalid"
    
#     constraint.expresssions.add() # TODO

# proc equal*[T](circuit: var Circuit[T], constant:Constant, constraint: Constraint[T]) {.inline.} =
#     circuit.equal(constraint, constant)

# TODO LT LTE GT GTE
# TODO LT LTE GT GTE for constant

proc inverse*[T](circuit: var Circuit[T], constraint: Constraint[T]): Constraint[T] =
    ## Inverses a constraint
    let expression = Expression[T](kind: SingleTerm,
            operation: DIV,
            term: Term[T](wire: constraint.outputWire, coefficient: ONE)
    )
    circuit.newConstraint(expression)

proc constrainBoolean*[T](circuit: var Circuit[T], constraints: varargs[Constraint[T]]) =
    ## Boolean Constrain a Constraint's output
    ## A boolean constraint $b \in \mathbb{B}$ is implemented as:
    ## $$(1-b) \times(b)=(0)$$ # TODO how does Nim docgen handle latex/mathbb?
    for constraint in constraints:
        for expression in circuit.zeroOutputs:
            if expression.kind == Boolean and expression.booleanWire == constraint.outputWire:
                return # already constrained
        
        for i, c in pairs(circuit.singleOutputs):
            if c == constraint:
                for expression in circuit.singleOutputs[i].expressions:
                    if expression.kind == XOR:
                        return # constraint is the result of a XOR expression, and already boolean constrained

        let expression = Expression[T](kind: Boolean, booleanWire: constraint.outputWire)
        circuit.zeroOutputs.add(expression)


proc `xor`*[T](circuit: var Circuit[T], a, b: Constraint[T]): Constraint[T] =
    # Ensure the constraints are constrained to booleans
    circuit.constrainBoolean(a, b)

    let expression = Expression[T](kind: XOR,
        a: a.outputWire,
        b: b.outputWire
    )
    circuit.newConstraint(expression)

## Binary (Un)packing

proc toBinary*[T](circuit: var Circuit[T], constraint: Constraint[T], numberOfBits: int): seq[Constraint[T]] =
    # Unpacks the constraints output wire to a number of bit constraints 
    var
        bitWires: seq[Wire] = @[]
        bits = newSeq[Constraint[T]](numberOfBits)
    for i in 0..<numberOfBits:
        bits[i] = circuit.newConstraint()
        circuit.constrainBoolean(bits[i])
        bitWires.add(bits[i].outputWire)

    let expression = Expression[T](kind: Unpack,
        res: constraint.outputWire,
        bits: bitWires
    )
    circuit.multiOutputs.add(expression)
    return bits
    
proc fromBinary*[T](circuit: var Circuit[T], bits: seq[Constraint[T]]): Constraint[T] =
    # Packs a set of bit constraints into a single constraint output wire
    let expression = Expression[T](kind: Pack, bits: @[])

    for constraint in bits:
        circuit.constrainBoolean(constraint)
        expression.bits.add(constraint.outputWire)
    
    circuit.newConstraint(expression)

proc fromBinary*[T](circuit: var Circuit[T], bit: Constraint[T]): Constraint[T] {.inline.} =
    circuit.fromBinary(@[bit])

## Selection

proc select*[T](circuit: var Circuit[T], b, x, y: Constraint[T]): Constraint[T] =
    ## if selector is true, then option1, else option2
    circuit.constrainBoolean(b)
    let expression = Expression[T](kind: Select,
        sb: b.outputWire,
        x: x.outputWire,
        y: y.outputWire
    )
    circuit.newConstraint(expression)

proc select*[T](circuit: var Circuit[T], b: Constraint[T], x, y: Constant): Constraint[T] =
    ## (b ? x : y) = z
    ## (b) x (y - x) = ( y - z )
    ## selector x (option2 - option1) = (option2 - z)
    circuit.constrainBoolean(b)
    
    let tmpCoefficient = y.toBigInt - x.toBigInt # TODO verify b(y-x)=(y-z)

    let expression = Expression[T](kind: Linear, operation: MUL,
        terms:  @[
            Term[T](wire: b.outputWire, coefficient: tmpCoefficient), # TODO both terms need to follow MUL
            Term[T](wire: circuit.oneWire, coefficient: ONE)
        ]
    )
    circuit.newConstraint(expression)

# TODO should select support mixed constraint, constant arguments ie turning the constant into a constraint?

proc lookup*[T](circuit: var Circuit[T], a,b: Constraint[T], table: array[4, Constant]) : Constraint[T] =
    ## where a and b are boolean, table[a*2+b]
    circuit.constrainBoolean(a, b)

    let expression = Expression[T](kind: Lookup,
        b0: a.outputWire,
        b1: b.outputWire,
        table: table
    )
    circuit.newConstraint(expression)