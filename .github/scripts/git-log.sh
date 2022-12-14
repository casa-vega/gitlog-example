#!/usr/bin/env bash

usage="$(basename "$0") [-h] [-tosf] [-r] -- capture all git logs in the org via clone --bare
OPTIONS:
   -t | --token <TOKEN>           GitHub API token (required)
   -o | --org  <ORG>              GitHub org name (required)
   -s | --server <HOSTNAME>       GitHub server hostname (e.g. github.company.com, required)
   -f | --file <PATH>             Path to file containing list of org repos (default: org_repos.txt)
   -h | --help                    Show this message.
EXAMPLE:
  $(basename "$0") -t <TOKEN> -o <ORG> -s <HOSTNAME>
"

FILE="org_repos.txt"

while true; do
  case "$1" in
  -h | --help)
    echo "$usage"
    exit
    ;;
  -t | --token)
    export TOKEN="$2"
    if [ -z "$TOKEN" ]; then
      echo "ERROR: token is required"
      echo "$usage"
      exit 1
    fi
    shift 2
    ;;
  -o | --org)
    export ORG="$2"
    if [ -z "$ORG" ]; then
      echo "ERROR: org is required"
      echo "$usage"
      exit 1
    fi
    shift 2
    ;;
  -s | --server)
    export SERVER="$2"
    if [ -z "$SERVER" ]; then
      echo "ERROR: server is required"
      echo "$usage"
      exit 1
    fi
    shift 2
    ;;
  -f | --file)
    export FILE="$2"
    if [ -z "$FILE" ]; then
      echo "ERROR: file path is required"
      echo "$usage"
      exit 1
    fi
    shift 2
    ;;
  -*)
    echo "Error: invalid argument: '$1'" 1>&2
    echo "$usage"
    exit 1
    ;;
  *)
    break
    ;;
  esac
done

# Loop through pagination to gather a list of repos from the org
COUNT=1
REQS=""
if [ ! -z ${SERVER} ]
then
  URL="https://$SERVER/api/v3/orgs/$ORG/repos?per_page=100"
else
  URL="https://api.github.com/orgs/$ORG/repos?per_page=100"
fi

while [ "$URL" ]; do
  RESP=$(curl -iSs -H "Authorization: token $TOKEN" "$URL")

  echo "$RESP" \
    | grep -o '"full_name": "[^"]*"' \
    | sed 's/"full_name": "//g' \
    | sed 's/"//g' >> "$FILE"

  HEADERS=$(echo "$RESP" \
    | sed '/^\r$/q')

  URL=$(echo "$HEADERS" \
    | sed -n -E 's/link:.*<(.*?)>; rel="next".*/\1/p')

  REQS="$REQS $(echo "$RESP" \
    | sed '1,/^\r$/d')"

  # send some feedback to the user
  echo "- gathering repo names, page $COUNT"
  COUNT=$((COUNT+1))
done

# read file into array
mapfile -t REPOS < "$FILE"

# create logging directory
mkdir logs

# loop through repos and collect git logs
for i in "${REPOS[@]}"; do
  REPO=$(basename $i)
  echo "- cloning $i repo"
  git clone --bare https://x-access-token:$TOKEN@github.com/$i.git $REPO
  cd $REPO
  echo "- redirecting git log STDOUT to file for $i repo"
  git log --pretty=format:%h,%an,%ae,%at,%D --all >> ../logs/$REPO.csv
  cd ..
  rm -rf $REPO
done

# remove list of repos and created directory
rm $FILE
# unset API token for good measure
unset TOKEN
