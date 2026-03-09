import CloudCore

extension AWS {
    public struct Cognito: AWSComponent {
        public let userPool: Resource
        public let userPoolClient: Resource
        public let userPoolDomain: Resource?
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
            domain: String? = nil,
            identityPool: Bool = false,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            userPool = Resource(
                name: name,
                type: "aws:cognito:UserPool",
                properties: ["name": name],
                options: options,
                context: context
            )

            userPoolClient = Resource(
                name: "\(name)-client",
                type: "aws:cognito:UserPoolClient",
                properties: [
                    "userPoolId": userPool.id,
                    "name": "\(name)-client",
                    "generateSecret": false,
                    "explicitAuthFlows": ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"],
                    "allowedOAuthFlowsUserPoolClient": true,
                    "allowedOAuthFlows": ["code"],
                    "allowedOAuthScopes": ["email", "openid", "profile"],
                    "callbackUrls": callbackUrls.isEmpty ? nil : callbackUrls,
                    "logoutUrls": logoutUrls.isEmpty ? nil : logoutUrls,
                    "supportedIdentityProviders": ["COGNITO"],
                ],
                options: options,
                context: context
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
