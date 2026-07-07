# Team coding guidelines

## Naming
Name every function with a verb; a bare-noun name is not allowed.

## Construction
Constructors must not do work beyond assigning their fields.

## Immutability
Every `record` type is immutable: no public setters — use init-only properties.

## Dependencies
The domain layer must not depend on the infrastructure layer.
