Command line application that produces version files based on version json and build. Every time you run `versionutil` it will update the build number in `version-build.json` and output to the version file of your choice, and optionally update a pom.xml file. 



version.json:
```
{"version":0,"revision":1,"patch":0}
```

version-build.json:
```
{"build":2}
```

- Modify pom.xml file version tag
- revision # should be padded to "00"
- Support major.minor.patch.build