import CloudCore

extension DigitalOcean {
    public struct Droplet: DigitalOceanResourceProvider {
        public let resource: Resource

        public var ipv4Address: Output<String> {
            resource.output.keyPath("ipv4Address")
        }

        public var ipv4AddressPrivate: Output<String> {
            resource.output.keyPath("ipv4AddressPrivate")
        }

        public var ipv6Address: Output<String> {
            resource.output.keyPath("ipv6Address")
        }

        public var urn: Output<String> {
            resource.output.keyPath("urn")
        }

        public var vcpus: Output<String> {
            resource.output.keyPath("vcpus")
        }

        public var memory: Output<String> {
            resource.output.keyPath("memory")
        }

        public var disk: Output<String> {
            resource.output.keyPath("disk")
        }

        public var status: Output<String> {
            resource.output.keyPath("status")
        }

        public var priceHourly: Output<String> {
            resource.output.keyPath("priceHourly")
        }

        public var priceMonthly: Output<String> {
            resource.output.keyPath("priceMonthly")
        }

        public init(
            _ name: String,
            image: Image,
            size: Size,
            region: Region = .nyc3,
            backups: Bool = false,
            monitoring: Bool = false,
            ipv6: Bool = false,
            sshKeys: [String] = [],
            userData: String? = nil,
            vpcUuid: Output<String>? = nil,
            tags: [String] = [],
            projectId: Output<String>? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            var properties: [String: Any] = [
                "name": tokenize(context.stage, name),
                "image": image.value,
                "size": size.rawValue,
                "region": region.rawValue,
                "backups": backups,
                "monitoring": monitoring,
                "ipv6": ipv6,
            ]

            if !sshKeys.isEmpty {
                properties["sshKeys"] = sshKeys
            }

            if let userData = userData {
                properties["userData"] = userData
            }

            if let vpcUuid = vpcUuid {
                properties["vpcUuid"] = vpcUuid
            }

            if !tags.isEmpty {
                properties["tags"] = tags
            }

            self.resource = .init(
                name: name,
                type: "digitalocean:Droplet",
                properties: .init(properties),
                options: options,
                context: context
            )

            if let projectId = projectId {
                let _ = Resource(
                    name: tokenize(name, "project-assignment"),
                    type: "digitalocean:ProjectResources",
                    properties: [
                        "project": projectId,
                        "resources": [self.urn]
                    ],
                    options: options,
                    context: context
                )
            }
        }
    }
}

extension DigitalOcean.Droplet {
    public enum Image: Sendable {
        case ubuntu_24_04
        case ubuntu_22_04
        case ubuntu_20_04
        case debian_12
        case debian_11
        case rockylinux_9
        case fedora_40
        case centos_stream_9
        case docker
        case custom(String)

        public var value: String {
            switch self {
            case .ubuntu_24_04:
                return "ubuntu-24-04-x64"
            case .ubuntu_22_04:
                return "ubuntu-22-04-x64"
            case .ubuntu_20_04:
                return "ubuntu-20-04-x64"
            case .debian_12:
                return "debian-12-x64"
            case .debian_11:
                return "debian-11-x64"
            case .rockylinux_9:
                return "rockylinux-9-x64"
            case .fedora_40:
                return "fedora-40-x64"
            case .centos_stream_9:
                return "centos-stream-9-x64"
            case .docker:
                return "docker-20-04"
            case .custom(let value):
                return value
            }
        }

        public var description: String {
            switch self {
            case .ubuntu_24_04:
                return "Ubuntu 24.04 LTS"
            case .ubuntu_22_04:
                return "Ubuntu 22.04 LTS"
            case .ubuntu_20_04:
                return "Ubuntu 20.04 LTS"
            case .debian_12:
                return "Debian 12"
            case .debian_11:
                return "Debian 11"
            case .rockylinux_9:
                return "Rocky Linux 9"
            case .fedora_40:
                return "Fedora 40"
            case .centos_stream_9:
                return "CentOS Stream 9"
            case .docker:
                return "Docker on Ubuntu 20.04"
            case .custom(let value):
                return "Custom: \(value)"
            }
        }
    }
}

extension DigitalOcean.Droplet {
    public enum Size: String, Sendable {
        // Basic Droplets
        case basic_1vCPU_512mb = "s-1vcpu-512mb-10gb"
        case basic_1vCPU_1gb = "s-1vcpu-1gb"
        case basic_1vCPU_2gb = "s-1vcpu-2gb"
        case basic_2vCPU_2gb = "s-2vcpu-2gb"
        case basic_2vCPU_4gb = "s-2vcpu-4gb"
        case basic_4vCPU_8gb = "s-4vcpu-8gb"
        case basic_8vCPU_16gb = "s-8vcpu-16gb"

        // General Purpose
        case gp_2vCPU_8gb = "g-2vcpu-8gb"
        case gp_4vCPU_16gb = "g-4vcpu-16gb"
        case gp_8vCPU_32gb = "g-8vcpu-32gb"
        case gp_16vCPU_64gb = "g-16vcpu-64gb"
        case gp_32vCPU_128gb = "g-32vcpu-128gb"

        // CPU-Optimized
        case cpu_2vCPU_4gb = "c-2"
        case cpu_4vCPU_8gb = "c-4"
        case cpu_8vCPU_16gb = "c-8"
        case cpu_16vCPU_32gb = "c-16"
        case cpu_32vCPU_64gb = "c-32"

        // Memory-Optimized
        case mem_2vCPU_16gb = "m-2vcpu-16gb"
        case mem_4vCPU_32gb = "m-4vcpu-32gb"
        case mem_8vCPU_64gb = "m-8vcpu-64gb"
        case mem_16vCPU_128gb = "m-16vcpu-128gb"
        case mem_32vCPU_256gb = "m-32vcpu-256gb"

        public var description: String {
            switch self {
            case .basic_1vCPU_512mb:
                return "Basic: 1 vCPU, 512MB RAM"
            case .basic_1vCPU_1gb:
                return "Basic: 1 vCPU, 1GB RAM"
            case .basic_1vCPU_2gb:
                return "Basic: 1 vCPU, 2GB RAM"
            case .basic_2vCPU_2gb:
                return "Basic: 2 vCPUs, 2GB RAM"
            case .basic_2vCPU_4gb:
                return "Basic: 2 vCPUs, 4GB RAM"
            case .basic_4vCPU_8gb:
                return "Basic: 4 vCPUs, 8GB RAM"
            case .basic_8vCPU_16gb:
                return "Basic: 8 vCPUs, 16GB RAM"
            case .gp_2vCPU_8gb:
                return "General Purpose: 2 vCPUs, 8GB RAM"
            case .gp_4vCPU_16gb:
                return "General Purpose: 4 vCPUs, 16GB RAM"
            case .gp_8vCPU_32gb:
                return "General Purpose: 8 vCPUs, 32GB RAM"
            case .gp_16vCPU_64gb:
                return "General Purpose: 16 vCPUs, 64GB RAM"
            case .gp_32vCPU_128gb:
                return "General Purpose: 32 vCPUs, 128GB RAM"
            case .cpu_2vCPU_4gb:
                return "CPU-Optimized: 2 vCPUs, 4GB RAM"
            case .cpu_4vCPU_8gb:
                return "CPU-Optimized: 4 vCPUs, 8GB RAM"
            case .cpu_8vCPU_16gb:
                return "CPU-Optimized: 8 vCPUs, 16GB RAM"
            case .cpu_16vCPU_32gb:
                return "CPU-Optimized: 16 vCPUs, 32GB RAM"
            case .cpu_32vCPU_64gb:
                return "CPU-Optimized: 32 vCPUs, 64GB RAM"
            case .mem_2vCPU_16gb:
                return "Memory-Optimized: 2 vCPUs, 16GB RAM"
            case .mem_4vCPU_32gb:
                return "Memory-Optimized: 4 vCPUs, 32GB RAM"
            case .mem_8vCPU_64gb:
                return "Memory-Optimized: 8 vCPUs, 64GB RAM"
            case .mem_16vCPU_128gb:
                return "Memory-Optimized: 16 vCPUs, 128GB RAM"
            case .mem_32vCPU_256gb:
                return "Memory-Optimized: 32 vCPUs, 256GB RAM"
            }
        }
    }
}
