#!/bin/sh -e

dir=$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd)

# Run black
echo "Running black..."
python3 -m black --check --diff "$dir"

# Run flake8
echo "Running flake8..."
python3 -m flake8 "$dir"

# Run mypy
echo "Running mypy..."
python3 -m mypy "$dir" "$dir/src"
