import ../circuit

# proc square*[T](circuit:Circuit, x: Constraint[T] | Constant): Constraint[T] =
#     x * x

circuit:
    proc square*(x:uint): uint = x * x