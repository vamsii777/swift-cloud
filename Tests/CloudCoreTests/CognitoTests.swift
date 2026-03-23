import Foundation
import Testing

@testable import CloudCore
import CloudAWS

@Suite("Cognito Tests")
struct CognitoTests {
    struct TestProject: Project {
        func build() async throws -> Outputs {
            [:]
        }
    }

    private func makeContext() -> Context {
        Context(
            stage: "testing",
            project: TestProject(),
            package: .init(name: "test"),
            store: .init(),
            builder: .init()
        )
    }

    private func decodeProperties(_ resource: Resource) throws -> [String: Any] {
        guard let properties = resource.properties else {
            return [:]
        }
        let data = try JSONEncoder().encode(properties)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func trustPolicyDocument(_ resource: Resource) throws -> [String: Any] {
        let properties = try decodeProperties(resource)
        let assumeRolePolicy = try #require(properties["assumeRolePolicy"] as? [String: Any])
        return try #require(assumeRolePolicy["fn::toJSON"] as? [String: Any])
    }

    private func roleStatement(_ resource: Resource) throws -> [String: Any] {
        let document = try trustPolicyDocument(resource)
        let statements = try #require(document["Statement"] as? [[String: Any]])
        return try #require(statements.first)
    }

    @Test("Identity pool keeps guest access off by default")
    func identityPoolDefaultsToAuthenticatedOnly() throws {
        let context = makeContext()
        _ = AWS.Cognito("auth", identityPool: true, context: context)

        let identityPool = try #require(
            context.store.resources.first { $0.type == "aws:cognito:IdentityPool" }
        )
        let properties = try decodeProperties(identityPool)

        #expect(properties["allowUnauthenticatedIdentities"] as? Bool == false)
    }

    @Test("Identity pool can enable guest access")
    func identityPoolCanEnableGuestAccess() throws {
        let context = makeContext()
        _ = AWS.Cognito(
            "auth",
            identityPool: true,
            allowUnauthenticatedIdentities: true,
            context: context
        )

        let identityPool = try #require(
            context.store.resources.first { $0.type == "aws:cognito:IdentityPool" }
        )
        let properties = try decodeProperties(identityPool)

        #expect(properties["allowUnauthenticatedIdentities"] as? Bool == true)
    }

    @Test("Identity pool attaches authenticated and unauthenticated roles")
    func identityPoolRoleAttachmentIncludesBothRoles() throws {
        let context = makeContext()
        _ = AWS.Cognito(
            "auth",
            identityPool: true,
            allowUnauthenticatedIdentities: true,
            context: context
        )

        let attachment = try #require(
            context.store.resources.first { $0.type == "aws:cognito:IdentityPoolRoleAttachment" }
        )
        let properties = try decodeProperties(attachment)
        let roles = try #require(properties["roles"] as? [String: Any])

        #expect(roles["authenticated"] != nil)
        #expect(roles["unauthenticated"] != nil)
        #expect(roles.count == 2)
    }

    @Test("Identity pool roles include Cognito trust conditions")
    func identityPoolRolesIncludeTrustConditions() throws {
        let context = makeContext()
        let cognito = AWS.Cognito(
            "auth",
            identityPool: true,
            allowUnauthenticatedIdentities: true,
            context: context
        )

        let authRole = try #require(
            context.store.resources.first { $0.type == "aws:iam:Role" && $0.chosenName.contains("auth-role") }
        )
        let unauthRole = try #require(
            context.store.resources.first { $0.type == "aws:iam:Role" && $0.chosenName.contains("unauth-role") }
        )

        let authStatement = try roleStatement(authRole)
        let unauthStatement = try roleStatement(unauthRole)

        let authCondition = try #require(authStatement["Condition"] as? [String: Any])
        let unauthCondition = try #require(unauthStatement["Condition"] as? [String: Any])
        let authStringEquals = try #require(authCondition["StringEquals"] as? [String: Any])
        let unauthStringEquals = try #require(unauthCondition["StringEquals"] as? [String: Any])

        let authPrincipal = try #require(authStatement["Principal"] as? [String: Any])
        let unauthPrincipal = try #require(unauthStatement["Principal"] as? [String: Any])

        #expect(authPrincipal["Federated"] as? String == "cognito-identity.amazonaws.com")
        #expect(unauthPrincipal["Federated"] as? String == "cognito-identity.amazonaws.com")
        #expect(authStatement["Action"] as? String == "sts:AssumeRoleWithWebIdentity")
        #expect(unauthStatement["Action"] as? String == "sts:AssumeRoleWithWebIdentity")
        #expect(authStringEquals["cognito-identity.amazonaws.com:aud"] as? String == cognito.identityPool?.id.description)
        #expect(unauthStringEquals["cognito-identity.amazonaws.com:aud"] as? String == cognito.identityPool?.id.description)
        #expect(authStringEquals["cognito-identity.amazonaws.com:amr"] as? String == "authenticated")
        #expect(unauthStringEquals["cognito-identity.amazonaws.com:amr"] as? String == "unauthenticated")
    }
}
