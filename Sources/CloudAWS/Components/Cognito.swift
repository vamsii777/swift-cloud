import CloudCore

extension AWS {
    public struct Cognito: AWSComponent {
        public let userPool: Resource
        public let userPoolClient: Resource
        public let userPoolDomain: Resource?
        public let identityProviders: [Resource]
        public let identityPool: Resource?
        public let authenticatedRole: Resource?
        public let unauthenticatedRole: Resource?
        public let identityPoolRoleAttachment: Resource?

        public var name: Output<String> { userPool.name }

        /// "https://cognito-idp.<region>.amazonaws.com/<poolId>" — JWT issuer URL
        public var issuerUrl: Output<String> {
            "https://\(userPool.output.keyPath("endpoint"))"
        }

        /// App client ID — used as JWT audience
        public var clientId: Output<String> { userPoolClient.id }

        /// Identity pool ID (nil when identityPool: false)
        public var identityPoolId: Output<String>? { identityPool?.id }

        public init(
            _ name: String,
            callbackUrls: [any Input<String>] = [],
            logoutUrls: [any Input<String>] = [],
            oauthScopes: [String] = [],
            domain: String? = nil,
            signInIdentifiers: Set<SignInIdentifier> = [.username],
            providers: [IdentityProvider] = [],
            attributeMappings: [String: [String: String]] = [:],
            identityPool: Bool = false,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            let fullName = tokenize(context.stage, name)
            let signInConfiguration = SignInConfiguration(identifiers: signInIdentifiers)
            let pool = Resource(
                name: name,
                type: "aws:cognito:UserPool",
                properties: [
                    "name": fullName,
                    "aliasAttributes": signInConfiguration.aliasAttributes,
                    "usernameAttributes": signInConfiguration.usernameAttributes,
                ],
                options: options,
                context: context
            )
            userPool = pool

            let providerResources: [Resource] = providers.map { provider in
                let mapping: [String: AnyEncodable] = attributeMappings[provider.providerName].map {
                    $0.mapValues { AnyEncodable($0) }
                } ?? provider.defaultAttributeMapping

                return Resource(
                    name: "\(name)-idp-\(provider.providerName.lowercased())",
                    type: "aws:cognito:UserPoolIdentityProvider",
                    properties: [
                        "userPoolId": pool.id,
                        "providerName": provider.providerName,
                        "providerType": provider.providerType,
                        "providerDetails": provider.providerDetails,
                        "attributeMapping": AnyEncodable(mapping),
                    ],
                    options: options,
                    context: context
                )
            }
            self.identityProviders = providerResources

            let oauthEnabled = !callbackUrls.isEmpty || !oauthScopes.isEmpty
            // code flow requires callbackUrls; client_credentials is for M2M (no redirect needed)
            let effectiveFlows: [String]? = oauthEnabled ? (!callbackUrls.isEmpty ? ["code"] : ["client_credentials"]) : nil
            let effectiveScopes: [String]? = oauthEnabled ? (!oauthScopes.isEmpty ? oauthScopes : ["email", "openid", "profile"]) : nil

            userPoolClient = Resource(
                name: "\(name)-client",
                type: "aws:cognito:UserPoolClient",
                properties: [
                    "userPoolId": pool.id,
                    "name": tokenize(context.stage, name, "client"),
                    "generateSecret": false,
                    "explicitAuthFlows": ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"],
                    "allowedOauthFlowsUserPoolClient": oauthEnabled,
                    "allowedOauthFlows": effectiveFlows,
                    "allowedOauthScopes": effectiveScopes,
                    "callbackUrls": callbackUrls.isEmpty ? nil : callbackUrls,
                    "logoutUrls": logoutUrls.isEmpty ? nil : logoutUrls,
                    "supportedIdentityProviders": ["COGNITO"] + providers.map { $0.providerName },
                ],
                options: options,
                context: context,
                dependsOn: providerResources.isEmpty ? nil : providerResources
            )

            if let domainValue = domain {
                userPoolDomain = Resource(
                    name: "\(name)-domain",
                    type: "aws:cognito:UserPoolDomain",
                    properties: [
                        "domain": domainValue,
                        "userPoolId": userPool.id,
                    ],
                    options: options,
                    context: context
                )
            } else {
                userPoolDomain = nil
            }

            if identityPool {
                let idPool = Resource(
                    name: "\(name)-identity-pool",
                    type: "aws:cognito:IdentityPool",
                    properties: [
                        "identityPoolName": "\(name)-identity-pool",
                        "allowUnauthenticatedIdentities": false,
                        "cognitoIdentityProviders": [[
                            "clientId": userPoolClient.id,
                            "providerName": userPool.output.keyPath("endpoint"),
                            "serverSideTokenCheck": false,
                        ]],
                    ],
                    options: options,
                    context: context
                )
                let authRole = Resource(
                    name: "\(name)-auth-role",
                    type: "aws:iam:Role",
                    properties: [
                        "assumeRolePolicy": Resource.JSON([
                            "Version": "2012-10-17",
                            "Statement": [[
                                "Effect": "Allow",
                                "Principal": ["Federated": "cognito-identity.amazonaws.com"],
                                "Action": "sts:AssumeRoleWithWebIdentity",
                            ]],
                        ])
                    ],
                    options: options,
                    context: context
                )
                let unauthRole = Resource(
                    name: "\(name)-unauth-role",
                    type: "aws:iam:Role",
                    properties: [
                        "assumeRolePolicy": Resource.JSON([
                            "Version": "2012-10-17",
                            "Statement": [[
                                "Effect": "Allow",
                                "Principal": ["Federated": "cognito-identity.amazonaws.com"],
                                "Action": "sts:AssumeRoleWithWebIdentity",
                            ]],
                        ])
                    ],
                    options: options,
                    context: context
                )
                let roleAttachment = Resource(
                    name: "\(name)-identity-pool-roles",
                    type: "aws:cognito:IdentityPoolRoleAttachment",
                    properties: [
                        "identityPoolId": idPool.id,
                        "roles": [
                            "authenticated": authRole.arn,
                            "unauthenticated": unauthRole.arn,
                        ],
                    ],
                    options: options,
                    context: context
                )
                self.identityPool = idPool
                self.authenticatedRole = authRole
                self.unauthenticatedRole = unauthRole
                self.identityPoolRoleAttachment = roleAttachment
            } else {
                self.identityPool = nil
                self.authenticatedRole = nil
                self.unauthenticatedRole = nil
                self.identityPoolRoleAttachment = nil
            }
        }
    }
}

extension AWS.Cognito: Linkable {
    public var actions: [String] {
        [
            "cognito-idp:AdminInitiateAuth",
            "cognito-idp:AdminCreateUser",
            "cognito-idp:AdminDeleteUser",
            "cognito-idp:AdminGetUser",
            "cognito-idp:AdminUpdateUserAttributes",
            "cognito-idp:AdminListGroupsForUser",
            "cognito-idp:AdminAddUserToGroup",
            "cognito-idp:AdminRemoveUserFromGroup",
            "cognito-idp:ListUsers",
            "cognito-idp:ListGroups",
        ]
    }

    public var resources: [Output<String>] { [userPool.arn] }

    public var properties: LinkProperties? {
        .init(
            type: "cognito",
            name: userPool.chosenName,
            properties: [
                "userPoolId": userPool.id,
                "clientId": clientId,
                "issuerUrl": issuerUrl,
            ]
        )
    }
}

extension AWS.Cognito {
    public enum SignInIdentifier: String, Hashable, Sendable {
        case username
        case email
        case phoneNumber
    }

    public enum IdentityProvider: Sendable {
        case google(clientId: any Input<String>, clientSecret: any Input<String>, scopes: [String] = ["email", "openid", "profile"])
        case facebook(appId: any Input<String>, appSecret: any Input<String>, scopes: [String] = ["email", "public_profile"])
        case apple(clientId: any Input<String>, teamId: any Input<String>, keyId: any Input<String>, privateKey: any Input<String>, scopes: [String] = ["email", "name"])
        case saml(name: String, metadataURL: (any Input<String>)? = nil, metadataContent: (any Input<String>)? = nil)
        case oidc(name: String, clientId: any Input<String>, clientSecret: any Input<String>, issuer: any Input<String>, scopes: [String] = ["email", "openid", "profile"], attributesRequestMethod: String = "GET")
    }
}

private struct SignInConfiguration {
    let aliasAttributes: [String]?
    let usernameAttributes: [String]?

    init(identifiers: Set<AWS.Cognito.SignInIdentifier>) {
        precondition(!identifiers.isEmpty, "Cognito signInIdentifiers cannot be empty.")

        let includesUsername = identifiers.contains(.username)
        let nonUsernameIdentifiers = identifiers.subtracting([.username])
        let attributes = nonUsernameIdentifiers
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.pulumiValue)

        if includesUsername {
            self.aliasAttributes = attributes.isEmpty ? nil : attributes
            self.usernameAttributes = nil
        } else {
            self.aliasAttributes = nil
            self.usernameAttributes = attributes
        }
    }
}

extension AWS.Cognito.IdentityProvider {
    var providerName: String {
        switch self {
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .apple: return "SignInWithApple"
        case .saml(let name, _, _): return name
        case .oidc(let name, _, _, _, _, _): return name
        }
    }

    var providerType: String {
        switch self {
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .apple: return "SignInWithApple"
        case .saml: return "SAML"
        case .oidc: return "OIDC"
        }
    }

    var providerDetails: AnyEncodable {
        switch self {
        case .google(let clientId, let clientSecret, let scopes):
            return [
                "client_id": AnyEncodable(clientId),
                "client_secret": AnyEncodable(clientSecret),
                "authorize_scopes": AnyEncodable(scopes.joined(separator: " ")),
            ]
        case .facebook(let appId, let appSecret, let scopes):
            return [
                "client_id": AnyEncodable(appId),
                "client_secret": AnyEncodable(appSecret),
                "authorize_scopes": AnyEncodable(scopes.joined(separator: ",")),
            ]
        case .apple(let clientId, let teamId, let keyId, let privateKey, let scopes):
            return [
                "client_id": AnyEncodable(clientId),
                "team_id": AnyEncodable(teamId),
                "key_id": AnyEncodable(keyId),
                "private_key": AnyEncodable(privateKey),
                "authorize_scopes": AnyEncodable(scopes.joined(separator: " ")),
            ]
        case .saml(_, let metadataURL, let metadataContent):
            precondition(
                (metadataURL == nil) != (metadataContent == nil),
                "SAML identity provider requires exactly one of metadataURL or metadataContent"
            )
            if let url = metadataURL {
                return ["MetadataURL": AnyEncodable(url)]
            } else {
                return ["MetadataFile": AnyEncodable(metadataContent!)]
            }
        case .oidc(_, let clientId, let clientSecret, let issuer, let scopes, let attributesRequestMethod):
            return [
                "client_id": AnyEncodable(clientId),
                "client_secret": AnyEncodable(clientSecret),
                "issuer": AnyEncodable(issuer),
                "authorize_scopes": AnyEncodable(scopes.joined(separator: " ")),
                "attributes_request_method": AnyEncodable(attributesRequestMethod),
            ]
        }
    }

    var defaultAttributeMapping: [String: AnyEncodable] {
        switch self {
        case .google:
            return ["email": "email", "username": "sub"]
        case .facebook:
            return ["email": "email", "username": "id"]
        case .apple:
            return ["email": "email", "username": "sub"]
        case .saml:
            return [
                "email": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
                "username": "nameID",
            ]
        case .oidc:
            return ["email": "email", "username": "sub"]
        }
    }
}

private extension AWS.Cognito.SignInIdentifier {
    var pulumiValue: String {
        switch self {
        case .username:
            return "username"
        case .email:
            return "email"
        case .phoneNumber:
            return "phone_number"
        }
    }
}
