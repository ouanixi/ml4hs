#! /usr/bin/env nix-shell
#! nix-shell -p jq -i bash
# set -e

# Exit code. Can stay at 0 or increase to 1. Should NEVER decrease from 1.
CODE=0

# We cache intermediate results in test-data. We have no cache invalidation,
# just delete it whenever you like.
mkdir -p test-data

function fail {
    echo "FAIL: $1"
    exit 1
}

function getRawAsts {
    F="test-data/$1.rawasts"
    [[ ! -e "$F" ]] &&
        ./dump-hackage.sh "$1" > "$F"
    cat "$F"
}

function getRawData {
    F="test-data/$1.rawdata"
    [[ ! -e "$F" ]] &&
        getRawAsts "$1" | ./runTypes.sh "$1" > "$F"
    cat "$F"
}

function getTypeCmd {
    F="test-data/$1.typeCmd"
    [[ ! -e "$F" ]] &&
        getRawData "$1" | jq -r '.cmd' > "$F"
    cat "$F"
}

function getTypeResults {
    F="test-data/$1.typeResults"
    [[ ! -e "$F" ]] &&
        getRawData "$1" | jq -r '.result' > "$F"
    cat "$F"
}

function getScopeCmd {
    F="test-data/$1.scopeCmd"
    [[ ! -e "$F" ]] &&
        getRawData "$1" | jq -r '.scopecmd' > "$F"
    cat "$F"
}

function getScopeResult {
    F="test-data/$1.scopeResult"
    [[ ! -e "$F" ]] &&
        getRawData "$1" | jq -r '.scoperesult' > "$F"
    cat "$F"
}

function getTypes {
    F="test-data/$1.types"
    [[ ! -e "$F" ]] &&
        getScopeResult "$1" | ./getTypes.sh > "$F"
    cat "$F"
}

function getArities {
    F="test-data/$1.arities"
    [[ ! -e "$F" ]] &&
        getTypeResults "$1" | ./getArities.sh > "$F"
    cat "$F"
}

function getTypeTagged {
    F="test-data/$1.typetagged"
    [[ ! -e "$F" ]] &&
        getRawAsts "$1" | ./tagAsts.sh <(getTypes "$1") > "$F"
    cat "$F"
}

function getArityTagged {
    F="test-data/$1.aritytagged"
    [[ ! -e "$F" ]] &&
        getRawAsts "$1" | ./tagAsts.sh <(getArities "$1") > "$F"
    cat "$F"
}

function getFeatures {
    F="test-data/$1.features"
    [[ ! -e "$F" ]] &&
        getRawAsts "$1" | ./extractFeatures.sh > "$F"
    cat "$F"
}

function getAsts {
    F="test-data/$1.asts"
    [[ ! -e "$F" ]] &&
        getRawData "$1" | ./annotateAsts.sh > "$F"
    cat "$F"
}

function getClusters {
    F="test-data/$1.clusters"
    [[ ! -e "$F" ]] &&
        getAsts "$1" | ./cluster.sh > "$F"
    cat "$F"
}

function getProjects {
    F="test-data/$1.projects"
    if [[ ! -e "$F" ]]
    then
        rm -rf "test-data/projects/$1" 2> /dev/null || true
        mkdir -p "test-data/projects/$1"
        getClusters "$1" | ./make-projects.sh "test-data/projects/$1" > "$F"
    fi
    cat "$F"
}

function getNixedProjects {
    F="test-data/$1.nixed"
    if [[ ! -e "$F" ]]
    then
        rm -rf "test-data/nixed/$1" 2> /dev/null || true
        mkdir -p "test-data/nixed"
        cp -r "test-data/projects/$1" "test-data/nixed/$1"
        (shopt -s nullglob;
         for PROJECT in "test-data/nixed/$1"/*
         do
             readlink -f "$PROJECT" >> "$F"
         done)
        ./nix-projects.sh < "$F"
    fi
    cat "$F"
}

function assertNotEmpty {
    COUNT=$(count "^")
    [[ "$COUNT" -gt 0 ]] || fail "$1"
}

function assertJsonNotEmpty {
    COUNT=$(jq -r "length")
    [[ "$COUNT" -gt 0 ]] || fail "$1"
}

function count {
    PAT="^"
    [ -n "$1" ] && PAT="$1"
    set +e
    grep -c "$PAT"
    set -e
}

function testGetRawAsts {
    getRawAsts     "$1" | assertJsonNotEmpty "Couldn't get raw ASTs from '$1'"
}

function testGetRawData {
    getRawData     "$1" | assertJsonNotEmpty "Couldn't get raw data from '$1'"
}

function testGetTypeCmd {
    getTypeCmd     "$1" | assertNotEmpty "Couldn't get type command from '$1'"
}

function testGetTypeResults {
    getTypeResults "$1" | assertNotEmpty "Couldn't get type info from '$1'"
}

function testGetScopeCmd {
    getScopeCmd    "$1" | assertNotEmpty "Couldn't get scoped command from '$1'"
}

function testGetScopeResult {
    getScopeResult "$1" | assertNotEmpty "Couldn't get scoped type info from '$1'"
}

function testGetTypes {
    getTypes       "$1" | assertJsonNotEmpty "Couldn't get types from '$1'"
}

function testGetArities {
    getArities     "$1" | assertJsonNotEmpty "Couldn't get arities from '$1'"
}

function testGetTypeTagged {
    getTypeTagged  "$1" | assertJsonNotEmpty "Couldn't get typed ASTs from '$1'"
}

function testGetArityTagged {
    getArityTagged "$1" | assertJsonNotEmpty "Couldn't get ASTs with aritiesfrom '$1'"
}

function testGetAsts {
    getAsts        "$1" | assertJsonNotEmpty "Couldn't get ASTs from '$1'"
}

function testAstFields {
       COUNT=$(getAsts "$1" | jq -c 'length')
        PKGS=$(getAsts "$1" | jq -c 'map(.package)  | length')
        MODS=$(getAsts "$1" | jq -c 'map(.module)   | length')
       NAMES=$(getAsts "$1" | jq -c 'map(.name)     | length')
        ASTS=$(getAsts "$1" | jq -c 'map(.ast)      | length')
       TYPES=$(getAsts "$1" | jq -c 'map(.type)     | length')
     ARITIES=$(getAsts "$1" | jq -c 'map(.arity)    | length')
    FEATURES=$(getAsts "$1" | jq -c 'map(.features) | length')
    [[ $COUNT -eq $PKGS     ]] || fail "$FUNCNAME '$1' pkgs"
    [[ $COUNT -eq $MODS     ]] || fail "$FUNCNAME '$1' mods"
    [[ $COUNT -eq $NAMES    ]] || fail "$FUNCNAME '$1' names"
    [[ $COUNT -eq $ASTS     ]] || fail "$FUNCNAME '$1' asts"
    [[ $COUNT -eq $TYPES    ]] || fail "$FUNCNAME '$1' types"
    [[ $COUNT -eq $ARITIES  ]] || fail "$FUNCNAME '$1' arities"
    [[ $COUNT -eq $FEATURES ]] || fail "$FUNCNAME '$1' features"
}

function testAstLabelled {
    getAsts "$1" | jq -c '.[] | .package' |
        while read -r LINE
        do
            [[ "x$LINE" = "x\"$1\"" ]] || fail "$FUNCNAME $1 $LINE"
        done
}

function testAllTypeCmdPresent {
    getAsts "$1" | jq -c -r '.[] | .module + "." + .name' |
        while read -r LINE
        do
            getTypeCmd "$1" | grep "('$LINE)" > /dev/null ||
                fail "$LINE not in '$1' type command"
        done
}

function testNoCoreNames {
    COUNT=$(getAsts "$1" | jq -r '.[] | .name' | count '\.\$')
    [[ "$COUNT" -eq 0 ]] ||
        fail "ASTs for '$1' contain Core names beginning with \$"
}

function testGetFeatures {
    getFeatures "$1" | assertNotEmpty "Couldn't get features from '$1'"
}

function countCommas {
    tr -dc ',' | wc -c
}

function testFeaturesUniform {
    RAWFEATURES=$(getFeatures "$1" | jq -r '.[] | .features' | grep ",")
    COUNT=$(echo "$RAWFEATURES" | head -n 1 | countCommas)
    echo "$RAWFEATURES" |
        while read LINE
        do
            THIS=$(echo "$LINE" | countCommas)
            if [[ "$THIS" -ne "$COUNT" ]]
            then
                fail "'$LINE' doesn't have $COUNT commas"
            fi
        done
}

function testHaveAllClusters {
    # FIXME: Make cluster number configurable (eg. so we can have it vary based
    # on the number of definitions)
    COUNT=$(getClusters "$1" | jq -r 'length')
    if [[ "$COUNT" -ne 4 ]]
    then
        fail "Found $COUNT clusters for '$1' instead of 4"
    fi
}

function testClusterFields {
    COUNT=$(getClusters "$1" | jq -r '.[] | length')
    getClusters "$1" | jq 'map(select(has("")))'
}

function absent {
    while read LINE
    do
        if [[ "x$LINE" = "x$1" ]]
        then
            return 1
        fi
    done
    return 0
}

function testProjectsMade {
    getProjects "$1" |
        while read PROJECT
        do
            if [[ ! -e "$PROJECT" ]]
            then
                fail "Directory '$PROJECT' not made for '$1'"
            fi
        done
}

function testNixFilesMade {
    getNixedProjects "$1" | while read PROJECT
                            do
                                if [[ ! -e "$PROJECT" ]]
                                then
                                    fail "'$PROJECT' not found for '$1'"
                                fi
                                if [[ ! -e "$PROJECT/shell.nix" ]]
                                then
                                    fail "'$PROJECT/shell.nix' missing for '$1'"
                                fi
                            done
}

function testNixProjectsRun {
    getNixedProjects "$1" | ./run-projects.sh
}

function testPackage {
    TESTS=(testGetRawAsts testGetRawData testGetTypeCmd testGetTypeResults
           testGetScopeCmd testGetScopeResult testGetTypes testGetArities
           testGetTypeTagged testGetArityTagged testGetAsts testAstFields
           testAstLabelled testAllTypeCmdPresent testNoCoreNames testGetFeatures
           testFeaturesUniform testHaveAllClusters testProjectsMade
           testNixFilesMade testNixProjectsRun)
    for TEST in ${TESTS[*]}
    do
        $TEST "$1"
        echo "PASS: '$TEST' '$1'"
    done
}

function testTagging {
    INPUT1='[{"name": "n1", "module": "M1"}, {"name": "n2", "module": "M2"}]'
    INPUT2='[{"name": "n2", "module": "M2", "foo": "bar"}]'
    RESULT=$(echo "$INPUT1" | ./tagAsts.sh <(echo "$INPUT2"))
    TYPE=$(echo "$RESULT" | jq 'type')
    [[ "x$TYPE" == 'x"array"' ]] || fail "tagAsts.sh gave '$TYPE' not array"
}

# "Unit" style tests
testTagging
echo "PASS: testTagging"

# Run on a selection of packages:
#  - directory doesn't have any Ord instances, since everything's return type is
#    `IO foo`
#  - quickspec because meta
#  - attoparsec because it's a decent size and exposeis a dependency of our Haskell
#    code
for PKG in data-stringmap MissingH attoparsec directory quickspec
do
    testPackage "$PKG"
    echo "PASS: testPackage '$PKG'"
done

exit "$CODE"
