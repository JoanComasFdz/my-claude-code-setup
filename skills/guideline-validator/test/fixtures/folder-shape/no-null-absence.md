# No null as absence
Never use `null` to signal "no value". Model absence with an explicit optional type.
A method that may have no result returns `Optional<T>`, never a nullable reference.
