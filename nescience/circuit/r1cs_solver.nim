import stint, tables

import types, utils

import bncurve as bn256
import ../algebra/fft

const MAX_ORDER = 28 # BN256 TODO make this type conditional, or is it available from bncurve?

proc instantiate[T](constraint: R1Constraint, r1cs: R1CS, wireValues: seq[T]): tuple[a,b,c:T] =
    var a, b, c:T
    template instantiate(expression: seq[R1Term], fieldElement: var T) =
        for term in expression:
            assert wireValues.len > term.id,
                "Attempted to access out of bound wire {term.id}" # TODO re-add &"...
            var tmp: T
            tmp = term.coefficient * wireValues[term.id]
            fieldElement = fieldElement + tmp

    constraint.L.instantiate(a)
    constraint.R.instantiate(b)
    constraint.O.instantiate(c)
    result = (a, b, c)

proc solve[T](constraint: R1Constraint[T], wireInstantiated: var seq[bool], wireValues: var seq[T]) =
    # search for unset wires and compute them, the r1cs is assumed to be correctly ordered
    var
        id: int64
        location: array[3, int64] = [-1'i64, -1'i64, -1'i64]
        tmp, a, b, c, backupCoefficient: T

    # a = T.zero()

    template instantiate[T](expression: seq[R1Term[T]], fieldElement: T, pos: int64) =
        var fieldElement = T.zero()
        for term in expression:
            if wireInstantiated[term.id]:
                fieldElement = fieldElement + (term.coefficient * wireValues[term.id])
            else:
                backupCoefficient = term.coefficient
                location[pos] = term.id
                
    
    case constraint.solver:
    of SingleOutput:
        constraint.L.instantiate(a, 0)
        constraint.R.instantiate(b, 1)
        constraint.O.instantiate(c, 2)

        template instantiate(id: int64, expression, subElement: T) =
            wireValues[id] = expression
            wireValues[id] = wireValues[id] - subElement
            wireValues[id] = wireValues[id] * backupCoefficient
        
        if location[0] != -1:
            let id = location[0]
            if b.isZero: wireValues[id].setZero()
            else:
                let (quot, rem) = divmod(c, b) # TODO this needs to support BigInts and Field Elements
                instantiate(id, quot, a)
            wireInstantiated[location[0]] = true
        elif location[1] != -1:
            let id = location[1]
            if a.isZero: wireValues[id].setZero()
            else:
                let (quot, rem) = divmod(c, a) # TODO this needs to support BigInts and Field Elements
                instantiate(id, quot, b)
            wireInstantiated[id] = true
        elif location[2] != -1:
            id = location[2]
            instantiate(id, a * b, c)
            wireInstantiated[id] = true
    of BinaryDecomposition:
        assert false, "BinaryDecomposition Not Implemented"
        # let
        #     n = wireValues[constraint.O[0].id] # TODO must be called on the non Mont form of the number
        #     numberOfBits = constraint.L.len

        # var i,j:int = 0
        # while i*64 < numberOfBits:
        #     j = 0
        #     while j < 64 and i*64+j < constraint.L.len:
        #         let ithBit = (n[i].uint shr j.uint)
        #         if not wireInstantiated[constraint.L[i*64+j].id]:
        #             wireValues[constraint.L[i*64+j].id] = ithbit.i256 # TODO BigInt
        #             wireInstantiated[constraint.L[i*64+j].id] = true
        #         j.inc
        #     i.inc



proc solve[T](r1cs: R1CS[T], solution: Solution, a,b,c,wireValues: var seq[T]) =
    assert a.len == r1cs.numberOfConstraints
    assert b.len == r1cs.numberOfConstraints
    assert c.len == r1cs.numberOfConstraints
    assert wireValues.len == r1cs.numberOfWires
    assert r1cs.privateWires.len == r1cs.numberOfPrivateWires
    assert r1cs.publicWires.len == r1cs.numberOfPublicWires

    var 
        wireInstantiated = newSeq[bool](r1cs.numberOfWires)
        offset: int64
        check: T

    template instantiateInputs(offset: int64, inputKind: InputKind, inputWires: seq[string]) =
        # TODO should i move this template next to instantiate proc for housekeeping? will it still work?
        for i, input in inputWires: 
            let pos = i+offset
            # Solve the One Wire
            if input == ONE_WIRE: wireValues[pos] = T.one()
            else:
                # Solve the Private|Public Input Wire
                assert solution.hasKey(input),
                    "Could not find {input} in the solution" # TODO re-add &" .. " issue with strformat
                let inputSolution = solution[input]
                # wireValues[pos] = inputSolution.value
                # assert inputKind is inputSolution.kind,
                #     "InputKind mismatch {input} is {inputSolution.kind}, expecting {inputKind}"  # TODO re-add &" .. " strformat
                wireValues[pos] = T.fromString(inputSolution.value.toString()) # TODO this needs to support BigInts and Field Elements
            wireInstantiated[pos] = true

    if r1cs.numberOfPublicWires > 0:
        offset = r1cs.numberOfWires - r1cs.numberOfPublicWires
        instantiateInputs(offset, Public, r1cs.publicWires)

    if r1cs.numberOfPrivateWires > 0:
        offset -= r1cs.numberOfPrivateWires
        instantiateInputs(offset, Private, r1cs.privateWires)

    for i, constraint in r1cs.constraints:
        if i < r1cs.numberOfCOConstraints:
            constraint.solve(wireInstantiated, wireValues)

        (a[i], b[i], c[i]) = constraint.instantiate(r1cs, wireValues)
        # assert (a[i] * b[i]) == c[i],
        #     &"{a[i]} x {b[i]} != {c[i]}, Constraint Equality Check Failed, Aborting."
    

proc solve*[T: Int256](r1cs: R1CS[T], solution: Solution): tuple[a,b,c:seq[T]] = 
    # TODO support field elements, constrained to Int256 as a BigInt placeholder
    let
        root = T.one()
        fftDomain = newDomain[T](root, MAX_ORDER, r1cs.numberOfConstraints)
    var
        # abc should be of length r1cs.numberOfConstraints, with capacity of domain cardinality
        a, b, c = newSeqOfCap[T](fftDomain.cardinality)
        wireValues = newSeq[T](r1cs.numberOfWires)

    a.setLen(r1cs.numberOfConstraints)
    b.setLen(r1cs.numberOfConstraints)
    c.setLen(r1cs.numberOfConstraints)
    r1cs.solve(solution, a, b, c, wirevalues)
    return (a, b, c)

