import CloudCore
import Foundation

extension DigitalOcean {
    /// A DigitalOcean Droplet (virtual server) component.
    ///
    /// This component creates and manages a DigitalOcean Droplet, providing
    /// a virtual private server with full SSH access and customizable configuration.
    ///
    /// Example usage:
    /// ```swift
    /// let project = DigitalOcean.Project("my-project")
    ///
    /// let database = DigitalOcean.Database(
    ///     "postgres-db",
    ///     engine: .postgres(),
    ///     region: .nyc3
    /// )
    ///
    /// let server = DigitalOcean.Server(
    ///     "web-server",
    ///     project: project,
    ///     image: .ubuntu_24_04,
    ///     size: .basic_2vCPU_4gb,
    ///     region: .nyc3,
    ///     monitoring: true,
    ///     sshKeys: ["your-ssh-key-id"]
    /// )
    ///
    /// // Link database to server (provides connection info via environment variables)
    /// server.link(database)
    /// ```
    public struct Server: DigitalOceanComponent, EnvironmentProvider {
        public let droplet: Droplet
        public let environment: Environment

        public var name: Output<String> {
            droplet.resource.name
        }

        public var ipv4Address: Output<String> {
            droplet.ipv4Address
        }

        public var ipv4AddressPrivate: Output<String> {
            droplet.ipv4AddressPrivate
        }

        public var ipv6Address: Output<String> {
            droplet.ipv6Address
        }

        public var status: Output<String> {
            droplet.status
        }

        public var urn: Output<String> {
            droplet.urn
        }

        public init(
            _ name: String,
            project: DigitalOcean.Project? = nil,
            image: Droplet.Image = .ubuntu_24_04,
            size: Droplet.Size = .basic_1vCPU_1gb,
            region: Region = .nyc3,
            backups: Bool = false,
            monitoring: Bool = true,
            ipv6: Bool = false,
            sshKeys: [String] = [],
            userData: String? = nil,
            vpcUuid: Output<String>? = nil,
            environment: [String: any Input<String>]? = nil,
            tags: [String] = [],
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            self.environment = Environment(environment, shape: .keyValueList)

            self.droplet = Droplet(
                name,
                image: image,
                size: size,
                region: region,
                backups: backups,
                monitoring: monitoring,
                ipv6: ipv6,
                sshKeys: sshKeys,
                userData: userData,
                vpcUuid: vpcUuid,
                tags: tags,
                projectId: project?.id,
                options: options,
                context: context
            )
        }
    }
}

extension DigitalOcean.Server: Linkable {
    public var actions: [String] {
        ["*"]
    }

    public var resources: [Output<String>] {
        [droplet.resource.id]
    }

    public var properties: LinkProperties? {
        return .init(
            type: "droplet",
            name: droplet.resource.chosenName,
            properties: [
                "ipv4Address": ipv4Address,
                "ipv4AddressPrivate": ipv4AddressPrivate,
                "ipv6Address": ipv6Address,
            ]
        )
    }
}

extension DigitalOcean.Server {
    /// Link a database or other linkable resource to this server
    @discardableResult
    public func link(_ linkable: any Linkable) -> Self {
        environment.merge(linkable.environmentVariables)
        return self
    }

    /// Link multiple linkable resources to this server
    @discardableResult
    public func link(_ linkables: [any Linkable]) -> Self {
        for linkable in linkables {
            link(linkable)
        }
        return self
    }

    /// Link multiple linkable resources to this server (variadic)
    @discardableResult
    public func link(_ linkables: any Linkable...) -> Self {
        return link(linkables)
    }
}
