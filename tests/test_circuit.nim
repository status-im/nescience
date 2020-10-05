import unittest, stint, sequtils
import tables

import ../nescience/circuit
# import ../nescience/proof_systems/groth16

test "Input - toConstraint":
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.sub(s, x)

    circuit.equal(sEqual, y)

    let r1cs = circuit.toR1CS()

    echo r1cs

    let solution = {
        "s": newInput(3, Private),
        "sEqual": newInput(-42, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "toConstraint - Input":
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.sub(x, s)

    circuit.equal(sEqual, y)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "s": newInput(3, Private),
        "sEqual": newInput(42, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "toConstraint + Input":
    # s(3) + x(45) = sEqual(48)
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.add(s, x)

    circuit.equal(sEqual, y)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "s": newInput(3, Private),
        "sEqual": newInput(48, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]


test "toConstraint + Constant + Input":
    # s(34) + x(45) + 93 = sEqual(172)
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    # let y = circuit.toConstraint(93)

    let output = circuit.add(s, x, 93)

    circuit.equal(sEqual, output)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "s": newInput(34, Private),
        "sEqual": newInput(172, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "toConstraint + toConstraint":
    # s(34) + x(45) + y(93) = sEqual(172)
    var circuit = newCircuit()
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.toConstraint(93)

    let output = circuit.add(x, y)

    circuit.equal(sEqual, output)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "sEqual": newInput(138, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "Input + toConstraint + toConstraint":
    # s(34) + x(45) + y(93) = sEqual(172)
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.toConstraint(93)

    let output = circuit.add(s, x, y)

    circuit.equal(sEqual, output)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "s": newInput(34, Private),
        "sEqual": newInput(172, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "select constraint":
    var circuit = newCircuit()
    let s = circuit.input("s", Private)
    let sEqual = circuit.input("sEqual", Public)

    let x = circuit.toConstraint(45)
    let y = circuit.toConstraint(93)

    let output = circuit.select(s, x, y)

    circuit.equal(sEqual, output)

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "s": newInput(1, Private),
        "sEqual": newInput(45, Public)
    }.toTable
    
    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]
    
# test "select constant": # TODO
#     var circuit = newCircuit()
#     let s = circuit.input("s", Private)
#     let sEqual = circuit.input("sEqual", Public)

#     let output = circuit.select(s, 45, 93)

#     circuit.equal(sEqual, output)

#     let r1cs = circuit.toR1CS()
#     echo r1cs

#     let solution = {
#         "s": newInput(1, Private),
#         "sEqual": newInput(45, Public)
#     }.toTable
    
#     let (a,b,c) = r1cs.solve(solution)

#     for i in 0..<r1cs.numberOfConstraints:
#         echo a[i], " x ", b[i], " = ", c[i]
#         check (a[i] * b[i]) == c[i]

# test "exponentiation":
#     ## x^e == y
#     ## 
#     var circuit = newCircuit()
    
#     let x = circuit.input("x", Public)
#     let e = circuit.input("e", Private)
#     let y = circuit.input("y", Public)

#     var output = circuit.toConstraint(1)
    
#     let bits = circuit.toBinary(e, 8) # 8 bits
#     for i, bit in bits:
#         if i != 0:
#             output = circuit.mul(output, output)
#         let multiply = circuit.mul(output, x)
        
#         echo "what is ", bits[bits.len-1-i] # TODO this seems wrong
#         output = circuit.select(bits[bits.len-1-i], multiply, output)
    
#     circuit.equal(y, output)
    
#     let r1cs = circuit.toR1CS()
    
#     let solution = {
#         "x": newInput(2, Public),
#         "e": newInput(12, Private),
#         "y": newInput(4096, Public)
#     }.toTable
    
#     let (a,b,c) = r1cs.solve(solution)


test "cubic equation":
    ## x^3 + x + 5 = y
    ## 
    var circuit = newCircuit()
    let x = circuit.input("x", Private)
    let y = circuit.input("y", Public)

    check x.outputWire.private == true
    check y.outputWire.private == false

    let x3 = circuit.mul(x, x, x)
    let x3x5 = circuit.add(x3, x, 5)
    circuit.equal(y, x3x5)

    # echo $circuit

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "x": newInput(3, Private),
        "y": newInput(35, Public)
    }.toTable

    let (a,b,c) = r1cs.solve(solution)
    
    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

    # let r1cs_bn256 = cast[R1CS[bn256.FR]](r1cs)
    # echo r1cs_bn256
    # r1cs_bn256.solve(solution)

test "subtraction":
    # 20 - 5 - 2 - 1 - 6 = 6
    var circuit = newCircuit()
    let x = circuit.input("x", Private)
    let y = circuit.input("y", Public)
    circuit.equal(y, circuit.sub(x, 5, 2, 1, 6))

    let r1cs = circuit.toR1CS()
    echo r1cs

    let solution = {
        "x": newInput(20, Private),
        "y": newInput(6, Public)
    }.toTable

    let (a,b,c) = r1cs.solve(solution)

    check a == @[15, 13, 12, 6].toBigInt
    check b == @[1, 1, 1, 1].toBigInt
    check c == @[15, 13, 12, 6].toBigInt

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

# # test "circuit dsl":

# #     # circuit circuit(Int256):
# #     #     ## y = x^3 + x + 5
# #     #     proc main(x:Private, y:Public) =
# #     #         let x2 = x * x
# #     #         var x3 = x2 * x
# #     #         let x4 = x3 + x
# #     #         let x5 = x4 + 5
# #     #         return x5 == y
    
# #     # circuit factor:
# #     #     ## a * b = c
# #     #     proc main(a,b:Private[int], c:Public[int]):int =
# #     #         return a * b == c

# #     # let witness = factor.generateWitness(private, public, out?)
# #     # let r1cs = factor.generateR1CS()

# #     # circuit circuit:
# #     #     ## x**3 + x * 5 = y
# #     #     proc main*(x:Private, y:Public) =
# #     #         let x3 = x^3
# #     #         return y == x3 + x * 5
    
