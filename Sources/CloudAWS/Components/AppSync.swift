extension AWS {
    public struct AppSync: AWSComponent {
        public let api: Resource
        
        public var name: Output<String> {
            api.name
        }
        
        public var id: Output<String> {
            api.id
        }
        
        public var arn: Output<String> {
            api.arn
        }
        
        public var graphqlUrl: Output<String> {
            api.output.keyPath("uris.GRAPHQL")
        }
        
        public var realtimeUrl: Output<String> {
            api.output.keyPath("uris.REALTIME")
        }
        
        public init(
            _ name: String,
            schema: String,
            authenticationType: AuthenticationType = .apiKey,
            additionalAuthenticationProviders: [AuthenticationType] = [],
            xrayEnabled: Bool = false,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            api = Resource(
                name: name,
                type: "aws:appsync:GraphQLApi",
                properties: [
                    "name": name,
                    "authenticationType": authenticationType.rawValue,
                    "schema": schema,
                    "xrayEnabled": xrayEnabled,
                    "additionalAuthenticationProviders": additionalAuthenticationProviders.isEmpty ? nil : additionalAuthenticationProviders.map { provider in
                        ["authenticationType": provider.rawValue]
                    }
                ],
                options: options,
                context: context
            )
        }
    }
}

extension AWS.AppSync {
    public enum AuthenticationType: String, Sendable {
        case apiKey = "API_KEY"
        case awsIam = "AWS_IAM"
        case amazonCognitoUserPools = "AMAZON_COGNITO_USER_POOLS"
        case openidConnect = "OPENID_CONNECT"
        case awsLambda = "AWS_LAMBDA"
    }
}

extension AWS.AppSync {
    @discardableResult
    public func addDataSource(
        _ name: String,
        type: DataSourceType,
        serviceRole: AWS.Role? = nil,
        options: Resource.Options? = nil,
        context: Context = .current
    ) -> Resource {
        switch type {
        case .dynamoDB(let config):
            return Resource(
                name: "\(api.chosenName)-\(name)-datasource",
                type: "aws:appsync:DataSource",
                properties: [
                    "apiId": api.id,
                    "name": name,
                    "type": "AMAZON_DYNAMODB",
                    "serviceRoleArn": serviceRole?.arn,
                    "dynamodbConfig": config.region == nil 
                        ? ["tableName": config.tableName]
                        : [
                            "tableName": config.tableName,
                            "region": config.region!
                          ]
                ],
                options: options ?? api.options,
                context: context
            )
        case .lambda(let config):
            return Resource(
                name: "\(api.chosenName)-\(name)-datasource",
                type: "aws:appsync:DataSource",
                properties: [
                    "apiId": api.id,
                    "name": name,
                    "type": "AWS_LAMBDA",
                    "serviceRoleArn": serviceRole?.arn,
                    "lambdaConfig": [
                        "functionArn": config.functionArn
                    ]
                ],
                options: options ?? api.options,
                context: context
            )
        case .http(let config):
            return Resource(
                name: "\(api.chosenName)-\(name)-datasource",
                type: "aws:appsync:DataSource",
                properties: [
                    "apiId": api.id,
                    "name": name,
                    "type": "HTTP",
                    "httpConfig": [
                        "endpoint": config.endpoint
                    ]
                ],
                options: options ?? api.options,
                context: context
            )
        case .none:
            return Resource(
                name: "\(api.chosenName)-\(name)-datasource",
                type: "aws:appsync:DataSource",
                properties: [
                    "apiId": api.id,
                    "name": name,
                    "type": "NONE"
                ],
                options: options ?? api.options,
                context: context
            )
        }
    }
}

extension AWS.AppSync {
    public enum DataSourceType: Sendable {
        case dynamoDB(DynamoDBConfig)
        case lambda(LambdaConfig)
        case http(HTTPConfig)
        case none
    }
    
    public struct DynamoDBConfig: Sendable {
        public let tableName: Output<String>
        public let region: String?
        
        public init(tableName: Output<String>, region: String? = nil) {
            self.tableName = tableName
            self.region = region
        }
    }
    
    public struct LambdaConfig: Sendable {
        public let functionArn: Output<String>
        
        public init(functionArn: Output<String>) {
            self.functionArn = functionArn
        }
    }
    
    public struct HTTPConfig: Sendable {
        public let endpoint: String
        
        public init(endpoint: String) {
            self.endpoint = endpoint
        }
    }
}

extension AWS.AppSync {
    @discardableResult
    public func addResolver(
        _ name: String,
        typeName: String,
        fieldName: String,
        dataSource: Resource,
        requestTemplate: String? = nil,
        responseTemplate: String? = nil,
        options: Resource.Options? = nil,
        context: Context = .current
    ) -> Resource {
        return Resource(
            name: "\(api.chosenName)-\(name)-resolver",
            type: "aws:appsync:Resolver",
            properties: [
                "apiId": api.id,
                "type": typeName,
                "field": fieldName,
                "dataSource": dataSource.name,
                "requestTemplate": requestTemplate ?? "{}",
                "responseTemplate": responseTemplate ?? "$util.toJson($context.result)"
            ],
            options: options ?? api.options,
            context: context
        )
    }
}

extension AWS.AppSync {
    @discardableResult
    public func addApiKey(
        description: String? = nil,
        expires: String? = nil,
        options: Resource.Options? = nil,
        context: Context = .current
    ) -> Resource {
        return Resource(
            name: "\(api.chosenName)-api-key",
            type: "aws:appsync:ApiKey",
            properties: [
                "apiId": api.id,
                "description": description,
                "expires": expires
            ],
            options: options ?? api.options,
            context: context
        )
    }
}

extension AWS.AppSync: Linkable {
    public var actions: [String] {
        [
            "appsync:GraphQL"
        ]
    }
    
    public var resources: [Output<String>] {
        [arn]
    }
    
    public var properties: LinkProperties? {
        return .init(
            type: "appsync",
            name: api.chosenName,
            properties: [
                "name": name,
                "graphqlUrl": graphqlUrl,
                "realtimeUrl": realtimeUrl
            ]
        )
    }
}