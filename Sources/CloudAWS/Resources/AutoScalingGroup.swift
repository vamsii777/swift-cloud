import CloudCore

extension AWS {
    public struct AutoScalingGroup: AWSResourceProvider {
        public let resource: Resource

        public init(
            _ name: String,
            launchTemplate: LaunchTemplate,
            minSize: Int,
            maxSize: Int,
            desiredCapacity: Int,
            vpcZoneIdentifiers: Output<[String]>,
            targetGroupArns: [Output<String>]? = nil,
            healthCheckType: String = "ELB",
            healthCheckGracePeriod: Int = 300,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:autoscaling:Group",
                properties: [
                    "minSize": minSize,
                    "maxSize": maxSize,
                    "desiredCapacity": desiredCapacity,
                    "vpcZoneIdentifiers": vpcZoneIdentifiers,
                    "launchTemplate": [
                        "id": launchTemplate.id,
                        "version": "$Latest"
                    ],
                    "healthCheckType": healthCheckType,
                    "healthCheckGracePeriod": healthCheckGracePeriod,
                    "targetGroupArns": targetGroupArns,
                    "tags": [
                        [
                            "key": "AmazonECSManaged",
                            "value": "true",
                            "propagateAtLaunch": true
                        ]
                    ]
                ],
                options: options,
                context: context
            )
        }
    }
}
