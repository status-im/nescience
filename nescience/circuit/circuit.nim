import tables, stint

import types, utils

# Inputs

proc isInput*(wire: Wire): bool {.inline.} = wire.name != ""

proc hasInput*[T](circuit: var Circuit[T], name: string): bool =
    result = false
    for i, constraint in pairs(circuit.singleOutputs): # TODO seems like compiler bug if I omit pairs(), typed table with generic types bad?
        if constraint.outputWire.name == name:
            return true

proc newInput*(value: Constant, t: InputKind = Private): Input =
    Input(value: value.toBigInt, kind: t)

# Constraints

proc addConstraint*[T](circuit: var Circuit[T], constraint: var Constraint[T]) =
    assert constraint.id == -1,
        "Constraint has already been assigned an ID"
    constraint.id = circuit.singleOutputs.len
    circuit.singleOutputs[constraint.id] = constraint
    

proc newConstraint*[T](circuit: var Circuit[T], expressions: seq[Expression[T]]): Constraint[T] =
    result = Constraint[T](
        circuit: circuit,
        id: -1,
        outputWire: Wire(
            private: true,
            id: -1,
            constraintID: -1
        ),
        expressions: expressions
    )
    circuit.addConstraint(result)

proc newConstraint*[T](circuit: var Circuit[T], expression: Expression[T]): Constraint[T] {.inline.} =
    circuit.newConstraint(@[expression])


proc newConstraint*[T](circuit: var Circuit[T]): Constraint[T] {.inline.} =
    circuit.newConstraint(@[])

# Circuit

proc newCircuit*(T: typedesc = Int256): Circuit[T] =  
    var circuit = Circuit[T](
        singleOutputs: initTable[int64, Constraint[T]](),
        multiOutputs: @[],
        zeroOutputs: @[]
    )
    # The ONE wire is a dedicated signal for generating 1 in the circuit
    # Every circuit has one and it is treated like a public input
    # Allows us to instantiate each constant as an output signal for use in other expressions
    # TODO should oneWire just be an allocated constant expression, rather than a special case?
    var oneConstraint = Constraint[T](
        circuit: circuit,
        id: -1,
        outputWire: Wire(
            name: ONE_WIRE,
            id: -1,
            constraintID: -1,
            consumed: true
        ),
        # expressions: @[]
    )
    circuit.addConstraint(oneConstraint)
    return circuit


# Wires

proc oneConstraint*[T](circuit: var Circuit[T]): Constraint[T] {.inline.} = circuit.singleOutputs[int64(0)]
# TODO should oneWire just be an allocated constant expression?
proc oneWire*[T](circuit: var Circuit[T]): Wire {.inline.} = circuit.oneConstraint().outputWire

proc consumeWire*(wire: var Wire) {.inline.} =
    wire.consumed = true

proc consumeWires*(wires: var seq[Wire]) {.inline.} =
    for wire in wires.mitems:
        wire.consumeWire()

proc consumeWires*[T](term: var Term[T]) {.inline.} =
    term.wire.consumeWire()

proc consumeWires*[T](terms: var seq[Term[T]]) {.inline.} =
    for term in terms.mitems:
        term.consumeWires()

proc consumeWires*[T](expression: var Expression[T]) =
    case expression.kind:
    of SingleTerm:
        expression.term.consumeWires()
    of Quadratic:
        expression.leftTerms.consumeWires()
        expression.rightTerms.consumeWires()
    of Linear:
        expression.terms.consumeWires()
    of XOR:
        expression.a.consumeWire()
        expression.b.consumeWire()
    of Pack:
        expression.bits.consumeWires()
    of Unpack:
        expression.res.consumeWire()
    of Select:
        expression.sb.consumeWire()
        expression.x.consumeWire()
        expression.y.consumeWire()
    of Lookup:
        expression.b0.consumeWire()
        expression.b1.consumeWire()
    of Const, Boolean:
        discard


proc replaceWire*(wire: var Wire, oldWire, newWire:Wire) {.inline.} =
    if wire == oldWire:
        wire = newWire

proc replaceWire*[T](term: var Term[T], oldWire, newWire:Wire) {.inline.} =
    term.wire.replaceWire(oldWire, newWire)

proc replaceWire*(wires: var seq[Wire], oldWire, newWire:Wire) =
    for wire in wires.mitems:
        wire.replaceWire(oldWire, newWire)

proc replaceWire*[T](terms: var seq[Term[T]], oldWire, newWire:Wire, reduce:bool = false) =
    for term in terms.mitems:
        term.replaceWire(oldWire, newWire)
    
    # Reduce the terms by summing the duplicates
    # currently only for Linear expressions
    if reduce:
        for i in 0..<terms.len:
            for j in i+1..<terms.len:
                if terms[i].wire == terms[j].wire:
                    terms[i].coefficient += terms[i].coefficient
                if j == terms.len-1:
                    terms = terms[0 .. ^j]
                else:
                    terms.del(j)
                break

proc replaceWire*[T](expression: var Expression[T], oldWire, newWire: Wire) =
    case expression.kind:
    of SingleTerm:
        expression.term.replaceWire(oldWire, newWire)
    of Quadratic:
        expression.leftTerms.replaceWire(oldWire, newWire)
        expression.rightTerms.replaceWire(oldWire, newWire)
    of Linear:
        expression.terms.replaceWire(oldWire, newWire, true) # Reduce Linear Expression
    of Boolean:
        expression.booleanWire.replaceWire(oldWire, newWire)
    of XOR:
        expression.a.replaceWire(oldWire, newWire)
        expression.b.replaceWire(oldWire, newWire)
    of Pack:
        expression.bits.replaceWire(oldWire, newWire)
    of Unpack:
        expression.bits.replaceWire(oldWire, newWire)
        expression.res.replaceWire(oldWire, newWire)
    of Select:
        expression.sb.replaceWire(oldWire, newWire)
        expression.x.replaceWire(oldWire, newWire)
        expression.y.replaceWire(oldWire, newWire)
    of Lookup:
        expression.b0.replaceWire(oldWire, newWire)
        expression.b1.replaceWire(oldWire, newWire)
    of Const:
        discard