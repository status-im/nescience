import unittest, stint, sequtils
import tables

import ../nescience/circuit
# import ../nescience/proof_systems/groth16

import ../nescience/stdlib/math

test "DSL":
    # TODO handle if to select
    # handle assert
        # assert x OPERATOR y

    circuit test[Int256]:

        proc main(a,b:Private[uint], c:Public[uint]) =
            var s = math.square(a)
            var x = s + 5
            assert x == c

    let r1cs = test.toR1CS()
    echo r1cs

    let solution = {
        "a": newInput(3, Private),
        "b": newInput(9, Private),
        "c": newInput(14, Public)
    }.toTable

    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]

test "test cubic equation":

    circuit cubicEquation[Int256]:
        ## x**3 + x * 5 = y
        proc main(x:Private[uint], y:Public[uint]) =
            var s = x^3
            var s1 = x * 5
            var s2 = s + s1
            assert y == s2
    
    let r1cs = cubicEquation.toR1CS()
    echo r1cs

    let solution = {
        "x": newInput(3, Private),
        "y": newInput(42, Public)
    }.toTable

    let (a,b,c) = r1cs.solve(solution)

    for i in 0..<r1cs.numberOfConstraints:
        echo a[i], " x ", b[i], " = ", c[i]
        check (a[i] * b[i]) == c[i]
