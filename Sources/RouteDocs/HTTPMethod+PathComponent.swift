import Vapor

extension HTTPMethod {
    struct InvalidPathComponentError: Error, CustomStringConvertible {
        let component: PathComponent
        var description: String { "The path component '\(component)' is invalid for \(HTTPMethod.self)" }
    }

    init(pathComponent: PathComponent) throws {
        switch pathComponent {
        case .constant(let val):
            self.init(rawValue: val)
        case .anything, .catchall, .parameter(_):
            throw InvalidPathComponentError(component: pathComponent)
        }
    }
}
