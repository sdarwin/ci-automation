
## Example files

coverage.1.json

```
gcovr -p --json --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter ".*/$REPONAME/.*" --output $BOOST_CI_SRC_FOLDER/json/coverage.1.json
```

coverage.2.json

```
gcovr -p --json --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter ".*/$REPONAME/.*" --output $BOOST_CI_SRC_FOLDER/json/coverage.2.json
```

summary.1.json

```
gcovr -p --json-summary --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter ".*/$REPONAME/.*" --output $BOOST_CI_SRC_FOLDER/json/summary.1.json
```

summary.2.json

```
gcovr -p --json-summary --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter ".*/$REPONAME/.*" --output $BOOST_CI_SRC_FOLDER/json/summary.2.json
```

webpages/

Processing of set 1:

```
gcovr -p --html-details --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter ".*/$REPONAME/.*" --html --output $BOOST_CI_SRC_FOLDER/gcovr/index.html
```
