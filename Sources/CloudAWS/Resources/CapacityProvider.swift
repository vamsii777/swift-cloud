extension AWS {
    public struct CapacityProvider: AWSResourceProvider {
        public let resource: Resource

        public init(
            _ name: String,
            autoScalingGroup: AutoScalingGroup,
            targetCapacity: Int = 100,
            minimumScalingStepSize: Int = 1,
            maximumScalingStepSize: Int = 100,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:ecs:CapacityProvider",
                properties: [
                    "autoScalingGroupProvider": [
                        "autoScalingGroupArn": autoScalingGroup.arn,
                        "managedScaling": [
                            "status": "ENABLED",
                            "targetCapacity": targetCapacity,
                            "minimumScalingStepSize": minimumScalingStepSize,
                            "maximumScalingStepSize": maximumScalingStepSize,
                            "instanceWarmupPeriod": 300
                        ],
                        "managedTerminationProtection": "ENABLED",
                        "managedDraining": "ENABLED"
                    ]
                ],
                options: options,
                context: context
            )
        }
    }
}
