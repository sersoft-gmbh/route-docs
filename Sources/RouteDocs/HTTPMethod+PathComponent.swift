import Vapor

extension HTTPMethod {
    struct InvalidPathComponentError: Error, Debuggable {
        let identifier: String = "HTTPMethod.InvalidPathComponent"
        let component: PathComponent
        var reason: String {
            return "The path component '\(component)' is invalid for \(HTTPMethod.self)"
        }
    }

    init(pathComponent: PathComponent) throws {
        switch pathComponent {
        case .constant(let val):
            guard let method = HTTPMethod(rawValue: val) else {
                throw InvalidPathComponentError(component: pathComponent)
            }
            self = method
        case .anything, .catchall, .parameter(_):
            throw InvalidPathComponentError(component: pathComponent)
        }
    }
}
