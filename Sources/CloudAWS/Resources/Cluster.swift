extension AWS {
    public struct Cluster: AWSResourceProvider {
        public let resource: Resource
        private let capacityProviders: Resource?

        public init(
            _ name: String,
            capacityProviderStrategy: CapacityProviderStrategy = .fargate,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:ecs:Cluster",
                properties: nil,
                options: options,
                context: context
            )

            capacityProviders = switch capacityProviderStrategy {
            case .fargate:
                Resource(
                    name: "\(name)-ccp",
                    type: "aws:ecs:ClusterCapacityProviders",
                    properties: [
                        "clusterName": resource.name,
                        "capacityProviders": ["FARGATE", "FARGATE_SPOT"],
                        "defaultCapacityProviderStrategies": [
                            [
                                "capacityProvider": "FARGATE",
                                "weight": 1,
                                "base": 1,
                            ],
                            [
                                "capacityProvider": "FARGATE_SPOT",
                                "weight": 1,
                            ],
                        ],
                    ],
                    options: options,
                    context: context
                )
            case .ec2(let provider):
                Resource(
                    name: "\(name)-ccp",
                    type: "aws:ecs:ClusterCapacityProviders",
                    properties: [
                        "clusterName": resource.name,
                        "capacityProviders": [provider.name],
                        "defaultCapacityProviderStrategies": [
                            [
                                "capacityProvider": provider.name,
                                "weight": 1,
                                "base": 1,
                            ]
                        ],
                    ],
                    options: options,
                    context: context
                )
            case .none:
                nil
            }
        }
    }
}

extension AWS.Cluster {
    public enum CapacityProviderStrategy: Sendable {
        case fargate
        case ec2(AWS.CapacityProvider)
        case none
    }
}
