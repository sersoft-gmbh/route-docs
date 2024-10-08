public import Vapor
public import LeafKit
public import Leaf

extension DocsViewContext {
    public static let defaultDocsViewPath: String = {
        Bundle.module.path(forResource: "DefaultDocsView", ofType: nil)!.finished(with: "/")
    }()
}

extension ViewRenderer {
    public func renderDefaultDocs(with context: DocsViewContext) async throws -> View {
        try await render("docs", context)
    }
}

extension NIOLeafFiles {
    /// The default leaf source for the docs.
    /// - Parameter fileio: The non-blocking File IO to use.
    /// - Returns: The NIO files instance that represents the bundled default docs.
    public static func defaultDocs(with fileio: NonBlockingFileIO) -> Self {
        NIOLeafFiles(fileio: fileio,
                     limits: [.onlyLeafExtensions, .toSandbox, .requireExtensions], // We must not insert .toVisibleFiles or we can't load from the `.build` directory.
                     sandboxDirectory: DocsViewContext.defaultDocsViewPath,
                     viewDirectory: DocsViewContext.defaultDocsViewPath,
                     defaultExtension: "leaf")
    }
}

extension Application {
    /// The default leaf source for the docs.
    @inlinable
    public var defaultDocsLeafSource: some LeafSource { NIOLeafFiles.defaultDocs(with: fileio) }
}

extension LeafSources {
    /// This registers the source "docs" using the given fileio.
    /// - Parameter fileio: The non-blocking File IO to use.
    @inlinable
    public func addDefaultDocsSource(with fileio: NonBlockingFileIO) throws {
        try register(source: "docs", using: NIOLeafFiles.defaultDocs(with: fileio))
    }

    /// This registers the source "docs" in the given application
    /// - Parameter app: The application in which to register the source.
    @inlinable
    public func addDefaultDocsSource(for app: Application) throws {
        try register(source: "docs", using: app.defaultDocsLeafSource)
    }
}

extension LeafRenderer {
    @inlinable
    public func addDefaultDocsSource(with fileio: NonBlockingFileIO) throws {
        try sources.addDefaultDocsSource(with: fileio)
    }
    
    @inlinable
    public func addDefaultDocsSource(for app: Application) throws {
        try sources.addDefaultDocsSource(for: app)
    }
}

extension Application.Leaf {
    /// Registers the tags needed to display the default docs.
    /// Currently this does nothing since we don't have any specific tags. This is reserved as a future improvement.
    public func registerDocumentationTags() {}

    @inlinable
    public func setupRouteDocs() throws {
        registerDocumentationTags()
        try sources.addDefaultDocsSource(for: application)
    }
}
