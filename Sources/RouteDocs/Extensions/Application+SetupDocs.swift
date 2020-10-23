import Vapor
import Leaf

extension DocsViewContext {
    public static let defaultDocsViewPath: String = {
        Bundle.module.path(forResource: "DefaultDocsView", ofType: nil)!.finished(with: "/")
    }()
}

extension ViewRenderer {
    public func renderDefaultDocs(with context: DocsViewContext) -> EventLoopFuture<View> {
        render(DocsViewContext.defaultDocsViewPath + "docs.leaf", context)
    }
}

extension NIOLeafFiles {
    public static func defaultDocs(with fileio: NonBlockingFileIO) -> Self {
        NIOLeafFiles(fileio: fileio,
                     limits: [.onlyLeafExtensions, .toSandbox, .requireExtensions], // We must not insert .toVisibleFiles or we can't load from the `.build` directory.
                     sandboxDirectory: DocsViewContext.defaultDocsViewPath,
                     viewDirectory: DocsViewContext.defaultDocsViewPath,
                     defaultExtension: "leaf")
    }
}

extension Application {
    @inlinable
    public var defaultDocsLeafSource: some LeafSource { NIOLeafFiles.defaultDocs(with: fileio) }
}

extension LeafSources {
    @inlinable
    public func addDefaultDocsSource(with fileio: NonBlockingFileIO) throws {
        try register(source: "docs", using: NIOLeafFiles.defaultDocs(with: fileio))
    }

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
    /// Currently this is:
    /// - escape: `EscapeTag`
    public func registerDocumentationTags() {
        tags["escaped"] = EscapeTag()
    }

    @inlinable
    public func setupRouteDocs() throws {
        registerDocumentationTags()
        try sources.addDefaultDocsSource(for: application)
    }
}
