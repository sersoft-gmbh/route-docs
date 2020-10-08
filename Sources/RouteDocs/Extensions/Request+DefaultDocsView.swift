import Vapor
import Leaf

extension DocsViewContext {
    public static let defaultDocsViewPath: String = {
        Bundle.module.path(forResource: "DefaultDocsView", ofType: nil)!.finished(with: "/")
    }()
}

extension ViewRenderer {
    public func renderDefaultDocs(with context: DocsViewContext) -> EventLoopFuture<View> {
        render(DocsViewContext.defaultDocsViewPath + "docs", context)
    }
}

extension NIOLeafFiles {
    public static func defaultDocs(with fileio: NonBlockingFileIO) -> Self {
        NIOLeafFiles(fileio: fileio,
                     limits: [.onlyLeafExtensions, .default],
                     sandboxDirectory: DocsViewContext.defaultDocsViewPath,
                     viewDirectory: DocsViewContext.defaultDocsViewPath,
                     defaultExtension: "leaf")
    }
}

extension Application {
    @inlinable
    public var defaultDocsLeafSource: some LeafSource { NIOLeafFiles.defaultDocs(with: fileio) }
}

extension LeafRenderer {
    @inlinable
    public func addDefaultDocsSource(with fileio: NonBlockingFileIO) throws {
        try sources.register(using: NIOLeafFiles.defaultDocs(with: fileio))
    }

    @inlinable
    public func addDefaultDocsSource(for app: Application) throws {
        try sources.register(using: app.defaultDocsLeafSource)
    }
}
