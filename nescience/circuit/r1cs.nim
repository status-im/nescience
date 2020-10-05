import tables, stint, sequtils, strformat, algorithm
import circuit, types, utils

proc assertKind(expression:Expression, kind:ExpressionKind) {.inline.} =
    assert expression.kind == kind,
        &"expression.kind != {kind}" 

proc toR1CS[T](term: Term[T], operation: Operation, oneWire: Wire, wire:Wire): R1Constraint[T] =
    let L = @[R1Term[T](id: term.wire.id, coefficient: term.coefficient)]
    var R, O = newSeq[R1Term[T]]()
    case operation:
    of MUL:
        R = @[R1Term[T](id: oneWire.id, coefficient: ONE)]
        O = @[R1Term[T](id: wire.id, coefficient: ONE)]
    of DIV:
        R = @[R1Term[T](id: wire.id, coefficient: ONE)]
        O = @[R1Term[T](id: oneWire.id, coefficient: ONE)]
    else:
        assert false, &"Term[T].toR1CS {operation} is Invalid"
    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)

proc toR1CS[T](terms: seq[Term[T]], oneWire: Wire, wire:Wire): R1Constraint[T] =
    var L = newSeq[R1Term[T]]()

    for term in terms:
        L.add(R1Term[T](id: term.wire.id, coefficient: term.coefficient)) 
    let
        R = @[R1Term[T](id: oneWire.id, coefficient: ONE)]
        O = @[R1Term[T](id: wire.id, coefficient: ONE)]

    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)

proc quadraticToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    assertKind expression, Quadratic
    var L, R, O = newSeq[R1Term[T]]()
    case expression.operation:
        of MUL:
            for term in expression.leftTerms:
                L.add(R1Term[T](id: term.wire.id, coefficient: term.coefficient))
            
            for term in expression.rightTerms:
                R.add(R1Term[T](id: term.wire.id, coefficient: term.coefficient))
            
            O = @[R1Term[T](id: wire.id, coefficient: ONE)]

            return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)
        of DIV:
            for term in expression.leftTerms:
                L.add(R1Term[T](id: term.wire.id, coefficient: term.coefficient))
            
            R = @[R1Term[T](id: wire.id, coefficient: ONE)]
            
            for term in expression.rightTerms:
                O.add(R1Term[T](id: term.wire.id, coefficient: term.coefficient))
            
            return R1Constraint[T](L:L, R:R, O:O)
        else:
            raise newException(ValueError, "Invalid operation for Quadratic Expression")

proc booleanToR1CS[T](expression: Expression[T], oneWire: Wire): R1Constraint[T] =
    assertKind expression, Boolean
    let
        L = @[R1Term[T](id: oneWire.id, coefficient: ONE),
              R1Term[T](id: expression.booleanWire.id, coefficient: -ONE)]
        R = @[R1Term[T](id: expression.booleanWire.id, coefficient: ONE)]
        O = @[R1Term[T](id: oneWire.id, coefficient: 0.toBigInt)] # TODO BigInt
    return R1Constraint[T](L:L, R:R, O:O)
    

proc xorToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    # TODO test
    assertKind expression, XOR
    let
        L = @[R1Term[T](id: expression.a.id, coefficient: TWO)]
        R = @[R1Term[T](id: expression.b.id, coefficient: ONE)]
        O = @[R1Term[T](id: expression.a.id, coefficient: ONE),
              R1Term[T](id: expression.b.id, coefficient: ONE),
              R1Term[T](id: wire.id, coefficient: -ONE)]
    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)

proc packToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    # TODO test
    assertKind expression, Pack
    var
        tmpL = newSeq[R1Term[T]]()
        accumulator = ONE
    
    for bitWire in expression.bits:
        tmpL.add(R1Term[T](id: bitWire.id, coefficient: accumulator))
        accumulator = accumulator * TWO

    let
        L = tmpL
        R = @[R1Term[T](id: oneWire.id, coefficient: ONE)]
        O = @[R1Term[T](id: wire.id, coefficient: ONE)]
    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)

proc unpackToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    # TODO test
    assertKind expression, Unpack
    var
        tmpL = newSeq[R1Term[T]]()
        accumulator = ONE
    
    for bitWire in expression.bits:
        tmpL.add(R1Term[T](id: bitWire.id, coefficient: accumulator))
        accumulator = accumulator * TWO

    let
        L = tmpL
        R = @[R1Term[T](id: oneWire.id, coefficient: ONE)]
        O = @[R1Term[T](id: expression.res.id, coefficient: ONE)]

    return R1Constraint[T](L:L, R:R, O:O, solver:BinaryDecomposition)

proc selectToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    assertKind expression, Select
    let
         # b
        L = @[R1Term[T](id: expression.sb.id, coefficient: ONE )]

        # * (y - x)
        R = @[R1Term[T](id: expression.y.id, coefficient: ONE ),
            R1Term[T](id: expression.x.id, coefficient: -ONE)]

        # = (y - z)
        O = @[R1Term[T](id: expression.y.id, coefficient: ONE ),
            R1Term[T](id: wire.id, coefficient: -ONE )]
    
    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)

# TODO proc lookupToR1CS[T](

proc constToR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire ): R1Constraint[T] =
    assertKind expression, Const
    let
        L = @[R1Term[T](id: oneWire.id, coefficient: expression.v )]
        R = @[R1Term[T](id: oneWire.id, coefficient: ONE )]
        O = @[R1Term[T](id: wire.id, coefficient: ONE )]

    return R1Constraint[T](L:L, R:R, O:O, solver:SingleOutput)


proc toR1CS[T](expression: Expression[T], oneWire: Wire, wire:Wire): R1Constraint[T] =
    case expression.kind:
    of SingleTerm:
        result = expression.term.toR1CS(expression.operation, oneWire, wire)
    of Quadratic:
        result = expression.quadraticToR1CS(oneWire, wire)
    of Linear:
        result = expression.terms.toR1Cs(oneWire, wire)
    of Boolean:
        assert wire == nil, &"Boolean Called with {wire}"
        result = expression.booleanToR1CS(oneWire)
    of XOR:
        result = expression.xorToR1CS(oneWire, wire)
    of Pack:
        result = expression.packToR1CS(oneWire, wire)
    of Unpack:
        result = expression.unpackToR1CS(oneWire, wire)
    of Select:
       result = expression.selectToR1CS(oneWire, wire)
    of Lookup:
        assert false, "Lookup.toR1CS Not Implemented"
    of Const:
        result = expression.constToR1CS(oneWire, wire)

proc toR1CS[T](constraint: Constraint[T], circuit: var Circuit[T]): seq[R1Constraint[T]] =
    result = newSeq[R1Constraint[T]]()
    for expression in constraint.expressions:
        result.add(expression.toR1CS(circuit.oneWire, constraint.outputWire))


proc findRootConstraints(wireTracker: seq[Wire]): seq[int64] =
    result = newSeq[int64]()
    for wire in wireTracker:
        if not wire.consumed:
            result.add(wire.constraintID)

proc reorderGraph[T](constraintID:int64, visitedConstraints: var seq[bool], computationalGraph: seq[R1Constraint[T]], graphOrdering: seq[int64], wireTracker: seq[Wire]): seq[int64] =
    var
       stackIn, stackOut = newSeq[int64]()
       node = constraintID
       found: bool
    
    stackIn.add(node)

    template traverseWires (wires: seq[R1Term[T]]) =
        # traverses L, R, O
        for w in wires:
            let n = wireTracker[w.id].constraintID
            if n != -1:
                if n != node and not visitedConstraints[n]:
                    stackIn.add(n)
                    found = true
                    node = n

    while stackIn.len != 0:
        # node = stackIn.pop()
        # stackIn.add(node)
        found = true

        while found:
            let constraint = computationalGraph[node]
            found = false
            traverseWires(constraint.L)
            if not found: traverseWires(constraint.R)
            if not found: traverseWires(constraint.O)
        
        node = stackIn.pop()
        stackOut.add(node)
        visitedConstraints[node] = true
    concat(graphOrdering, stackOut)
    
proc toR1CS*[T](circuit: var Circuit[T], t:typedesc = nil): R1CS[T] =
    var
        wireTracker, publicInputs, privateInputs = newSeq[Wire]()
        computationalGraph = newSeq[R1Constraint[T]]()
        keys:seq[int64] = @[]
        counter:int64 = 0

    for i, constraint in pairs(circuit.singleOutputs): # TODO seems like compiler bug if I omit pairs()
        if constraint.outputWire.isInput:
            if constraint.outputWire.private:
                privateInputs.add(circuit.singleOutputs[i].outputWire)
            else:
                publicInputs.add(circuit.singleOutputs[i].outputWire)
            keys.add(i)
        else:
            wireTracker.add(circuit.singleOutputs[i].outputWire)
            if constraint.expressions.len != 0:
                circuit.singleOutputs[i].expressions[0].consumeWires() # only the first expression is consumed, the other might contain root of the computational graph
                circuit.singleOutputs[i].outputWire.constraintID = counter
                counter.inc
                keys.add(i)

    for expression in circuit.multiOutputs.mitems:
        case expression.kind:
        of Unpack:
            for bit in expression.bits.mitems:
                bit.constraintID = counter
        else:
            discard
        expression.consumeWires()
        counter.inc

    for i, wire in wireTracker:
        wireTracker[i].id = int64(i)

    var offset = wireTracker.len
    
    var r1cs = R1CS[T](
        privateWires: newSeq[string](privateInputs.len),
        publicWires: newSeq[string](publicInputs.len)
    )

    for i, wire in privateInputs:
        privateInputs[i].id = int64(i + offset)
        r1cs.privateWires[i] = wire.name
        wireTracker.add(wire)

    offset.inc(privateInputs.len)

    for i, wire in publicInputs:
        publicInputs[i].id = int64(i + offset)
        r1cs.publicWires[i] = wire.name
        wireTracker.add(wire)

    # Convert Circuit Constraints to r1cs

    for id in keys:
        var constraint = circuit.singleOutputs[id]
        let r1constraint = constraint.toR1CS(circuit)

        if constraint.outputWire.isInput:
            r1cs.constraints.add(r1constraint)
        else:
            computationalGraph.add(r1constraint[0])
            if r1constraint.len > 1:
                r1cs.constraints.add(r1constraint[1..^1])

    for expression in circuit.multiOutputs:
        let r1constraint = expression.toR1CS(circuit.oneWire, nil)
        computationalGraph.add(r1constraint)

    for expression in circuit.zeroOutputs:
        let r1constraint = expression.toR1CS(circuit.oneWire, nil)
        r1cs.constraints.add(r1constraint)

    var
        visitedConstraints = newSeq[bool](computationalGraph.len)
        graphOrdering = newSeq[int64]()

    # Find Constraints that need to be solved first, then reorder the graph
    let rootConstraints = wireTracker.findRootConstraints()

    for constraintID in rootConstraints:
        graphOrdering = reorderGraph(constraintID, visitedConstraints, computationalGraph, graphOrdering, wireTracker)
    
    var constraints = newSeq[R1Constraint[T]](graphOrdering.len)
    for i, v in graphOrdering:
        constraints[i] = computationalGraph[graphOrdering[i]]
    
    r1cs.constraints = concat(constraints, r1cs.constraints)

    r1cs.numberOfWires = wireTracker.len
    r1cs.numberOfPrivateWires = privateInputs.len
    r1cs.numberOfPublicWires = publicInputs.len
    r1cs.numberOfConstraints = r1cs.constraints.len
    r1cs.numberOfCOConstraints = graphOrdering.len
    # TODO if t is defined, cast r1cs into type?
    return r1cs



