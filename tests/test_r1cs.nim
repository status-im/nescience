import unittest, stint

import ../nescience/languages/r1cs

test "load r1cs":
  let sumtest = r1cs.load("./tests/data/sumtest.bn-128.r1cs")
  check sumtest.headerSection.prime == u256("21888242871839275222246405745257275088548364400416034343698204186575808495617")
  check sumtest.headerSection.numberOfConstraints == 97 and len(sumtest.constraintSection.constraints) == 97