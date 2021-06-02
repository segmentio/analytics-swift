Releasing
=========

1. Update the version in Sources/Version.swift
2. `git commit -am "Version X.Y.Z"`
3. `git tag -a X.Y.Z -m "Version X.Y.Z"`
4. `git push && git push --tags`
5. Create a new github release at https://github.com/segmentio/analytics-swift/releases
    * Summarize change history in release notes.
