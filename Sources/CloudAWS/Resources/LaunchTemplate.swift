import CloudCore

extension AWS {
    public struct LaunchTemplate: AWSResourceProvider {
        public let resource: Resource

        public init(
            _ name: String,
            imageId: Output<String>,
            instanceType: String,
            instanceProfile: InstanceProfile,
            securityGroups: [Output<String>],
            userData: Output<String>,
            keyName: Output<String>? = nil,
            enableIMDSv2: Bool = true,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:ec2:LaunchTemplate",
                properties: [
                    "imageId": imageId,
                    "instanceType": instanceType,
                    "iamInstanceProfile": [
                        "arn": instanceProfile.arn
                    ],
                    "vpcSecurityGroupIds": securityGroups,
                    "userData": userData,
                    "keyName": keyName,
                    "metadataOptions": enableIMDSv2 ? [
                        "httpTokens": "required",
                        "httpPutResponseHopLimit": 1,
                        "instanceMetadataTags": "enabled"
                    ] : nil,
                    "tagSpecifications": [
                        [
                            "resourceType": "instance",
                            "tags": [
                                "Name": name
                            ]
                        ]
                    ]
                ],
                options: options,
                context: context
            )
        }
    }
}
