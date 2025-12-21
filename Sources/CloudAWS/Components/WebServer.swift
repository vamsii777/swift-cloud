import CloudCore
import Foundation

extension AWS {
    public struct WebServer: AWSComponent, EnvironmentProvider {
        public let cluster: AWS.Cluster
        public let dockerImage: DockerImage
        public let role: Role
        public let loadBalancerSecurityGroup: AWS.SecurityGroup
        public let instanceSecurityGroup: AWS.SecurityGroup
        public let secureDomainName: AWS.SecureDomainName?
        public let applicationLoadBalancer: Resource
        public let service: Resource
        public let concurrency: Int
        public let environment: Environment
        public let computeType: ComputeType

        public var instanceRole: Role?
        public var instanceProfile: InstanceProfile?
        public var launchTemplate: LaunchTemplate?
        public var autoScalingGroup: AutoScalingGroup?
        public var capacityProvider: CapacityProvider?
        public var taskDefinition: Resource?

        public var name: Output<String> {
            serviceName
        }

        public var chosenName: String {
            service.chosenName
        }

        public var region: Output<String> {
            getARN(cluster).region
        }

        public var serviceName: Output<String> {
            service.output.keyPath("service", "name")
        }

        public var clusterName: Output<String> {
            cluster.name
        }

        public var internalHostname: Output<String> {
            applicationLoadBalancer.output.keyPath("loadBalancer", "dnsName")
        }

        public var zoneId: Output<String> {
            applicationLoadBalancer.output.keyPath("loadBalancer", "zoneId")
        }

        public var hostname: Output<String> {
            if let secureDomainName {
                return secureDomainName.hostname
            } else {
                return internalHostname
            }
        }

        public var url: Output<String> {
            if let secureDomainName {
                return "https://\(secureDomainName.hostname)"
            } else {
                return "http://\(hostname)"
            }
        }

        public init(
            _ name: String,
            targetName: String,
            domainName: DomainName? = nil,
            concurrency: Int = 1,
            cpu: Int = 256,
            memory: Int = 512,
            architecture: Architecture = .current,
            computeType: ComputeType = .fargate,
            autoScaling: AutoScalingConfiguration? = nil,
            instancePort: Int = 8080,
            vpc: AWS.VPC? = nil,
            environment: [String: any Input<String>] = [:],
            arguments: [String]? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            self.concurrency = concurrency
            self.computeType = computeType

            if case .ec2(let config) = computeType {
                if config.enableSSH && config.sshKeyName == nil {
                    fatalError("SSH enabled but no key pair specified. Provide sshKeyName or disable SSH.")
                }

                if let minSize = config.minSize, minSize < 1 {
                    fatalError("minSize must be at least 1")
                }

                if let minSize = config.minSize, let maxSize = config.maxSize, maxSize < minSize {
                    fatalError("maxSize must be greater than or equal to minSize")
                }
            }

            let dockerFilePath = Docker.Dockerfile.filePath(name)

            self.environment = Environment(environment, shape: .nameValueList)
            self.environment["PORT"] = "\(instancePort)"

            let resolvedVpc = vpc ?? AWS.VPC.default(options: options)

            cluster = AWS.Cluster(
                "\(name)-cluster",
                capacityProviderStrategy: .none,
                options: options
            )

            dockerImage = DockerImage(
                "\(name)-image",
                imageRepository: .shared(options: options),
                dockerFilePath: dockerFilePath,
                options: options
            )

            role = AWS.Role(
                "\(name)-role",
                service: "ecs-tasks.amazonaws.com",
                options: options
            )

            switch computeType {
            case .fargate:
                instanceRole = nil
                instanceProfile = nil
                launchTemplate = nil
                autoScalingGroup = nil
                capacityProvider = nil
                taskDefinition = nil

            case .ec2(let config):
                instanceRole = AWS.Role(
                    "\(name)-instance-role",
                    service: "ec2.amazonaws.com",
                    options: options
                )

                _ = Resource(
                    name: "\(name)-instance-policy",
                    type: "aws:iam:RolePolicyAttachment",
                    properties: [
                        "role": instanceRole!.name,
                        "policyArn": "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
                    ],
                    options: options,
                    context: context
                )

                instanceProfile = AWS.InstanceProfile(
                    "\(name)-profile",
                    role: instanceRole!,
                    options: options
                )

                launchTemplate = nil // Temporarily nil, will be set below
                autoScalingGroup = nil // Temporarily nil, will be set below
                capacityProvider = nil // Temporarily nil, will be set below

                taskDefinition = Resource(
                    name: "\(name)-taskdef",
                    type: "aws:ecs:TaskDefinition",
                    properties: [
                        "family": "\(name)-task",
                        "networkMode": "awsvpc",
                        "requiresCompatibilities": ["EC2"],
                        "cpu": "\(cpu)",
                        "memory": "\(memory)",
                        "runtimePlatform": [
                            "cpuArchitecture": architecture.ecsArchitecture
                        ],
                        "containerDefinitions": Resource.JSON([
                            [
                                "name": "\(name)-container",
                                "image": dockerImage.uri,
                                "cpu": cpu,
                                "memory": memory,
                                "essential": true,
                                "portMappings": [
                                    [
                                        "containerPort": instancePort,
                                        "hostPort": instancePort,
                                        "protocol": "tcp"
                                    ]
                                ],
                                "environment": self.environment
                            ]
                        ]),
                        "taskRoleArn": role.arn
                    ],
                    options: options,
                    context: context
                )
            }

            loadBalancerSecurityGroup = AWS.SecurityGroup(
                "\(name)-lbsg",
                ingress: .all,
                egress: .all,
                options: options
            )

            instanceSecurityGroup = AWS.SecurityGroup(
                "\(name)-tsg",
                ingress: [.securityGroup(loadBalancerSecurityGroup)],
                egress: .all,
                options: options
            )

            secureDomainName = domainName.map {
                AWS.SecureDomainName(domainName: $0)
            }

            applicationLoadBalancer = Resource(
                name: "\(name)-alb",
                type: "awsx:lb:ApplicationLoadBalancer",
                properties: [
                    "listeners": [
                        secureDomainName
                            .map { ["port": 443, "protocol": "HTTPS", "certificateArn": $0.certificate.arn] }
                            ?? ["port": 80, "protocol": "HTTP"]
                    ],
                    "defaultTargetGroup": [
                        "port": instancePort,
                        "protocol": "HTTP",
                    ],
                    "defaultSecurityGroup": [
                        "securityGroupId": loadBalancerSecurityGroup.id
                    ],
                ],
                options: options,
                context: context,
                dependsOn: secureDomainName.map { [$0.validation] },
                maxNameLength: 24
            )

            if case .ec2(let config) = computeType {
                let imageId = config.ami.resolveImageId(architecture: architecture, context: context)
                let userData = Self.generateECSUserData(clusterName: "\(name)-cluster")

                launchTemplate = AWS.LaunchTemplate(
                    "\(name)-lt",
                    imageId: imageId,
                    instanceType: config.instanceType,
                    instanceProfile: instanceProfile!,
                    securityGroups: [instanceSecurityGroup.id],
                    userData: userData,
                    keyName: config.sshKeyName.map { "\($0)" },
                    enableIMDSv2: true,
                    options: options,
                    context: context
                )

                let minSize = config.minSize ?? concurrency
                let maxSize = config.maxSize ?? (autoScaling?.maximumConcurrency ?? concurrency * 2)

                autoScalingGroup = AWS.AutoScalingGroup(
                    "\(name)-asg",
                    launchTemplate: launchTemplate!,
                    minSize: minSize,
                    maxSize: maxSize,
                    desiredCapacity: concurrency,
                    vpcZoneIdentifiers: resolvedVpc.publicSubnetIds,
                    targetGroupArns: [applicationLoadBalancer.output.keyPath("defaultTargetGroup", "arn")],
                    options: options,
                    context: context
                )

                capacityProvider = AWS.CapacityProvider(
                    "\(name)-cp",
                    autoScalingGroup: autoScalingGroup!,
                    options: options,
                    context: context
                )

                _ = Resource(
                    name: "\(name)-ccp",
                    type: "aws:ecs:ClusterCapacityProviders",
                    properties: [
                        "clusterName": cluster.name,
                        "capacityProviders": [capacityProvider!.name],
                        "defaultCapacityProviderStrategies": [
                            [
                                "capacityProvider": capacityProvider!.name,
                                "weight": 1,
                                "base": 1,
                            ]
                        ],
                    ],
                    options: options,
                    context: context
                )
            } else {
                _ = Resource(
                    name: "\(name)-ccp",
                    type: "aws:ecs:ClusterCapacityProviders",
                    properties: [
                        "clusterName": cluster.name,
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
            }

            service = switch computeType {
            case .fargate:
                Resource(
                    name: "\(name)-service",
                    type: "awsx:ecs:FargateService",
                    properties: [
                        "cluster": cluster.arn,
                        "desiredCount": concurrency,
                        "continueBeforeSteadyState": true,
                        "forceNewDeployment": true,
                        "networkConfiguration": [
                            "assignPublicIp": true,
                            "securityGroups": [instanceSecurityGroup.id],
                            "subnets": resolvedVpc.publicSubnetIds,
                        ],
                        "triggers": [
                            "date": Date().formatted(.iso8601)
                        ],
                        "taskDefinitionArgs": [
                            "runtimePlatform": [
                                "cpuArchitecture": architecture.ecsArchitecture
                            ],
                            "container": [
                                "name": "\(name)-container",
                                "image": dockerImage.uri,
                                "cpu": cpu,
                                "memory": memory,
                                "essential": true,
                                "portMappings": [
                                    [
                                        "containerPort": instancePort,
                                        "hostPort": instancePort,
                                        "targetGroup": applicationLoadBalancer.output.keyPath("defaultTargetGroup"),
                                    ]
                                ],
                                "environment": self.environment,
                            ],
                            "taskRole": [
                                "roleArn": role.arn
                            ],
                            "trackLatest": true,
                        ],
                    ],
                    options: options,
                    context: context
                )
            case .ec2:
                Resource(
                    name: "\(name)-service",
                    type: "aws:ecs:Service",
                    properties: [
                        "cluster": cluster.arn,
                        "desiredCount": concurrency,
                        "taskDefinition": taskDefinition!.arn,
                        "capacityProviderStrategies": [
                            [
                                "capacityProvider": capacityProvider!.name,
                                "weight": 1,
                                "base": 1
                            ]
                        ],
                        "networkConfiguration": [
                            "assignPublicIp": true,
                            "securityGroups": [instanceSecurityGroup.id],
                            "subnets": resolvedVpc.publicSubnetIds,
                        ],
                        "loadBalancers": [
                            [
                                "targetGroupArn": applicationLoadBalancer.output.keyPath("defaultTargetGroup", "arn"),
                                "containerName": "\(name)-container",
                                "containerPort": instancePort
                            ]
                        ],
                        "forceNewDeployment": true,
                        "triggers": [
                            "date": Date().formatted(.iso8601)
                        ],
                    ],
                    options: options,
                    context: context
                )
            }

            if let autoScaling {
                enableAutoScaling(
                    minimumConcurrency: autoScaling.minimumConcurrency,
                    maximumConcurrency: autoScaling.maximumConcurrency,
                    metrics: autoScaling.metrics
                )
            }

            domainName?.aliasTo(internalHostname)

            context.store.build {
                let dockerFile: String
                if let arguments = arguments {
                    dockerFile = Docker.Dockerfile.ubuntu(
                        targetName: targetName,
                        port: instancePort,
                        arguments: arguments
                    )
                } else {
                    dockerFile = Docker.Dockerfile.ubuntu(
                        targetName: targetName,
                        port: instancePort
                    )
                }
                try Docker.Dockerfile.write(dockerFile, to: dockerFilePath)
                try await $0.builder.buildUbuntu(targetName: targetName)
            }
        }
    }
}

extension AWS.WebServer: RoleProvider {}

extension AWS.WebServer {
    public struct AutoScalingConfiguration: Sendable {
        public let minimumConcurrency: Int?
        public let maximumConcurrency: Int
        public let metrics: [AWS.AutoScaling.Metric]

        public init(
            minimumConcurrency: Int? = nil,
            maximumConcurrency: Int,
            metrics: [AWS.AutoScaling.Metric]
        ) {
            self.minimumConcurrency = minimumConcurrency
            self.maximumConcurrency = maximumConcurrency
            self.metrics = metrics
        }
    }

    @discardableResult
    public func enableAutoScaling(
        minimumConcurrency: Int? = nil,
        maximumConcurrency: Int,
        metrics: [AWS.AutoScaling.Metric]
    ) -> AWS.AutoScaling {
        .init(
            self,
            minimumConcurrency: minimumConcurrency ?? self.concurrency,
            maximumConcurrency: maximumConcurrency,
            metrics: metrics
        )
    }

    public enum ComputeType: Sendable {
        case fargate
        case ec2(EC2Configuration)
    }

    public struct EC2Configuration: Sendable {
        public let instanceType: String
        public let ami: AMI
        public let sshKeyName: String?
        public let enableSSH: Bool
        public let minSize: Int?
        public let maxSize: Int?

        public init(
            instanceType: String = "t3.micro",
            ami: AMI = .ecsOptimized,
            sshKeyName: String? = nil,
            enableSSH: Bool = false,
            minSize: Int? = nil,
            maxSize: Int? = nil
        ) {
            self.instanceType = instanceType
            self.ami = ami
            self.sshKeyName = sshKeyName
            self.enableSSH = enableSSH
            self.minSize = minSize
            self.maxSize = maxSize
        }
    }

    public enum AMI: Sendable {
        case ecsOptimized
        case custom(String)

        internal func resolveImageId(architecture: Architecture, context: Context = .current) -> Output<String> {
            switch self {
            case .ecsOptimized:
                let paramPath = architecture == .arm64
                    ? "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
                    : "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"

                let param = Resource(
                    name: "ecs-ami-\(architecture.dockerPlatform)",
                    type: "aws:ssm:getParameter",
                    properties: [
                        "name": paramPath
                    ],
                    options: nil,
                    context: context
                )
                return param.output.keyPath("value")
            case .custom(let amiId):
                return "\(amiId)"
            }
        }
    }

    private static func generateECSUserData(clusterName: String) -> Output<String> {
        let script = """
#!/bin/bash
echo ECS_CLUSTER=\(clusterName) >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
"""
        return "\(Data(script.utf8).base64EncodedString())"
    }
}
