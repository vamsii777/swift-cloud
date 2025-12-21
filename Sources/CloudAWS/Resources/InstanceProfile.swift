extension AWS {
    public struct InstanceProfile: AWSResourceProvider {
        public let resource: Resource

        public init(
            _ name: String,
            role: Role,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:iam:InstanceProfile",
                properties: [
                    "role": role.name
                ],
                options: options,
                context: context
            )
        }
    }
}
