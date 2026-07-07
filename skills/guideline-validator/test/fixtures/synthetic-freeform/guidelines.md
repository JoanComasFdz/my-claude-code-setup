# Team coding guidelines

## Naming
Name every function with a verb; a bare-noun name is not allowed.

## Construction
Constructors must not do work beyond assigning their fields.

## Design
Apply SOLID principles and keep the architecture clean and maintainable.

## Dependencies
The domain layer must never depend on the infrastructure layer.

## Control flow
A function must have exactly one `return` statement (single exit).
Use early-return guard clauses to keep nesting shallow.

## Documentation
Every public method must carry an XML `<summary>` doc comment.
All public members must be documented with `///` summary comments.
