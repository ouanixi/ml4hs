#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

# Monomorphic types come in via stdin

function trim {
    grep -o '[^ ].*[^ ]'
}

# Turn (foo)::bar::baz into foo\tbaz
grep '::' | sed 's/(\(.*\)).*::*.*::\(.*\)/\1\t\2/g' |
    while read -r LINE
    do
        # Cut at the \t, trim whitespace and reverse the (qualified) name
        RNAME=$(echo "$LINE" | cut -f 1 | trim | rev)
        TYPE=$( echo "$LINE" | cut -f 2 | trim)

        # Chop the reversed name at the first dot, eg. 'eman.2doM.1doM' gives
        # 'eman' and '2doM.1doM', then reverse to get 'name' and 'Mod1.Mod2'
        NAME=$(echo "$RNAME" | cut -d '.' -f 1  | rev)
        MODS=$(echo "$RNAME" | cut -d '.' -f 2- | rev)

        echo "{\"module\": \"$MODS\", \"name\": \"$NAME\", \"type\": \"$TYPE\"}"
    done | jq -s '.'
