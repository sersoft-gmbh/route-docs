# RouteDocs

[![GitHub release](https://img.shields.io/github/release/sersoft-gmbh/route-docs.svg?style=flat)](https://github.com/sersoft-gmbh/route-docs/releases/latest)
![Tests](https://github.com/sersoft-gmbh/route-docs/workflows/Tests/badge.svg)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/79e8965866ad4ed9a2cf4389c0a3a1a1)](https://www.codacy.com/gh/sersoft-gmbh/route-docs/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sersoft-gmbh/route-docs&amp;utm_campaign=Badge_Grade)
[![codecov](https://codecov.io/gh/sersoft-gmbh/route-docs/branch/master/graph/badge.svg?token=UUQetUQ4hG)](https://codecov.io/gh/sersoft-gmbh/route-docs)
[![Docs](https://img.shields.io/badge/-documentation-informational)](https://sersoft-gmbh.github.io/route-docs)

This adds some types and extensions to Vapor's `Route` type that allows documenting each route.
Also, a `ViewContext` object helps in bringing these documentations to a web page.
Finally, there's a default docs page to show all collected route documentation.

## Installation

Add the following dependency to your `Package.swift`:
```swift
.package(url: "https://github.com/sersoft-gmbh/route-docs", from: "2.0.0"),
```

## Compatibility

-   For Vapor up to version 3, use RouteDocs version 1.x.y.
-   For Vapor as of version 4, use RouteDocs version 2.x.y.

## Documentation

The API is documented using header doc. If you prefer to view the documentation as a webpage, there is an [online version](https://sersoft-gmbh.github.io/route-docs) available for you.

## Contributing

If you find a bug / like to see a new feature in RouteDocs there are a few ways of helping out:

-   If you can fix the bug / implement the feature yourself please do and open a PR.
-   If you know how to code (which you probably do), please add a (failing) test and open a PR. We'll try to get your test green ASAP.
-   If you can do neither, then open an issue. While this might be the easiest way, it will likely take the longest for the bug to be fixed / feature to be implemented.

## License

See [LICENSE](./LICENSE) file.
