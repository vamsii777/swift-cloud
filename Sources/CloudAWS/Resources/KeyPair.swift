extension AWS {
    public struct KeyPair: AWSResourceProvider {
        public let resource: Resource

        public init(
            _ name: String,
            publicKey: String? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            resource = Resource(
                name: name,
                type: "aws:ec2:KeyPair",
                properties: publicKey.map { ["publicKey": $0] },
                options: options,
                context: context
            )
        }
    }
}
