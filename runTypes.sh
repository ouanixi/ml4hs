#!/usr/bin/env bash

set -e

# Runs GHCi to get type information

function replLines {
    # Recombine any lines which GHCi split up
    while IFS= read -r LINE
    do
        if echo "$LINE" | grep '^ ' > /dev/null
        then
            printf  " ${LINE}"
        else
            printf "\n${LINE}"
        fi
    done
}

function repl {
    nix-shell -p "haskellPackages.ghcWithPackages (x: [x.QuickCheck x.quickspec x.$1])" \
              --run 'ghci -v0 -XTemplateHaskell'
}

function typeCommand {
    echo ":m"
    grep "^{" | while read -r LINE
                do
                    QNAME=$(echo "$LINE" | jq -r '.module + "." + .name')
                    mkQuery "$QNAME"
                done
}

function mkQuery {
    # Try to type-check QuickSpec signatures, to see which work
    # TODO: Higher-kinded morphism, eg. Functors and Monads

    # Shorthand
    QS="Test.QuickSpec"

    # Use Template Haskell to monomorphise our function (tries to
    # instantiate all type variables with "Integer")
    MONO="Test.QuickCheck.All.monomorphic ('$1)"

    # We must use a layer of let/in for TH to work, so we call our
    # monomorphic function "f"
    BIND="let f = \$($MONO) in"

    # Get the monomorphised type
    echo ":t $BIND f"

    # Try turning our monomorphised function into a QuickSpec Sig(nature)
    for NUM in 5 4 3 2 1 0
    do
        # Format the current arity and the (qualified) name as JSON
        JSON="\"{\\\"arity\\\": $NUM, \\\"qname\\\": \\\"$1\\\"}\""

        # Pass f to QuickSpec, using our JSON as the identifier
        SIG="$QS.fun${NUM} ($JSON) f"

        # Extract the JSON from the signature
        EXPR="$QS.Term.name (head ($QS.Signature.symbols ($SIG)))"

        # Print out the JSON, so we can spot it when we parse the results
        echo "$BIND putStrLn ($EXPR)"
    done
}

function typeScopes {
    # Make sure the types we've been given are actually available in scope (ie.
    # they're not off in some hidden package)
    echo ":m"
    grep "in f[ ]*::" |
        while IFS= read -r LINE
        do
            NAME=$(echo "$LINE" | sed -e "s/^.*('\(.*\)))[ ]*in f[ ]*::.*$/\1/g")
            TYPE=$(echo "$LINE" | sed -e "s/^.*::[ ]*\(.*\)$/\1/g")
            echo ":t ($NAME) :: ($TYPE)"
        done
}

ASTS=$(cat)
CMD=$(echo "$ASTS" | jq -c '.[]' | typeCommand)
RESULT=$(echo "$CMD" | repl "$1" | replLines)
SCOPECMD=$(echo "$RESULT" | typeScopes)
SCOPERESULT=$(echo "$SCOPECMD" | repl "$1" | replLines)

# Output everything as JSON
jq -n --argfile asts        <(echo "$ASTS")                       \
      --argfile cmd         <(echo "$CMD"         | jq -s -R '.') \
      --argfile result      <(echo "$RESULT"      | jq -s -R '.') \
      --argfile scopecmd    <(echo "$SCOPECMD"    | jq -s -R '.') \
      --argfile scoperesult <(echo "$SCOPERESULT" | jq -s -R '.') \
      '{asts: $asts, cmd: $cmd, result: $result, scopecmd: $scopecmd, scoperesult: $scoperesult}'
