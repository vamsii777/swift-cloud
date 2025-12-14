import CloudCore

extension DigitalOcean {
    public struct DatabaseCluster: DigitalOceanResourceProvider {
        public let resource: Resource

        public var hostname: Output<String> {
            resource.output.keyPath("host")
        }

        public var privateHostname: Output<String> {
            resource.output.keyPath("privateHost")
        }

        public var port: Output<String> {
            resource.output.keyPath("port")
        }

        public var user: Output<String> {
            resource.output.keyPath("user")
        }

        public var password: Output<String> {
            resource.output.keyPath("password")
        }

        public var database: Output<String> {
            resource.output.keyPath("database")
        }

        public var uri: Output<String> {
            resource.output.keyPath("uri")
        }

        public var privateUri: Output<String> {
            resource.output.keyPath("privateUri")
        }

        public init(
            _ name: String,
            engine: Engine,
            size: Size = .basic_1vCPU_1gb,
            region: Region = .nyc3,
            nodeCount: Int = 1,
            projectId: Output<String>? = nil,
            tags: [String] = [],
            maintenanceWindow: MaintenanceWindow? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            var properties: [String: Any] = [
                "name": tokenize(context.stage, name),
                "engine": engine.name,
                "version": engine.version,
                "size": size.rawValue,
                "region": region.rawValue,
                "nodeCount": nodeCount,
            ]

            if let projectId = projectId {
                properties["projectId"] = projectId
            }

            if !tags.isEmpty {
                properties["tags"] = tags
            }

            if let maintenanceWindow = maintenanceWindow {
                properties["maintenanceWindow"] = [
                    "day": maintenanceWindow.day.rawValue,
                    "hour": maintenanceWindow.hour
                ]
            }

            self.resource = .init(
                name: name,
                type: "digitalocean:DatabaseCluster",
                properties: .init(properties),
                options: options,
                context: context
            )
        }
    }
}

extension DigitalOcean.DatabaseCluster {
    public enum Engine: Sendable {
        case postgres(_ version: PostgresVersion = .v18)
        case mysql(_ version: MySQLVersion = .v8_0)
        case valkey
        case mongodb(_ version: MongoDBVersion = .v8)
        case kafka
        case opensearch(_ version: OpenSearchVersion = .v2)

        public var name: String {
            switch self {
            case .postgres:
                return "pg"
            case .mysql:
                return "mysql"
            case .valkey:
                return "valkey"
            case .mongodb:
                return "mongodb"
            case .kafka:
                return "kafka"
            case .opensearch:
                return "opensearch"
            }
        }

        public var version: String {
            switch self {
            case .postgres(let version):
                return version.rawValue
            case .mysql(let version):
                return version.rawValue
            case .valkey:
                return "8"
            case .mongodb(let version):
                return version.rawValue
            case .kafka:
                return "3.7"
            case .opensearch(let version):
                return version.rawValue
            }
        }

        public var scheme: String {
            switch self {
            case .postgres:
                return "postgres"
            case .mysql:
                return "mysql"
            case .valkey:
                return "valkey"
            case .mongodb:
                return "mongodb"
            case .kafka:
                return "kafka"
            case .opensearch:
                return "opensearch"
            }
        }

        public var defaultPort: Int {
            switch self {
            case .postgres:
                return 25060
            case .mysql:
                return 25060
            case .valkey:
                return 25061
            case .mongodb:
                return 27017
            case .kafka:
                return 9092
            case .opensearch:
                return 25060
            }
        }
    }

    public enum PostgresVersion: String, Sendable {
        case v18 = "18"
        case v17 = "17"
        case v16 = "16"
        case v15 = "15"
        case v14 = "14"
    }

    public enum MySQLVersion: String, Sendable {
        case v8_0 = "8"
    }

    public enum MongoDBVersion: String, Sendable {
        case v8 = "8"
        case v7 = "7"
    }

    public enum OpenSearchVersion: String, Sendable {
        case v2 = "2"
    }
}

extension DigitalOcean.DatabaseCluster {
    public enum Size: String, Sendable {
        // Basic tier
        case basic_1vCPU_1gb = "db-s-1vcpu-1gb"
        case basic_1vCPU_2gb = "db-s-1vcpu-2gb"
        case basic_2vCPU_4gb = "db-s-2vcpu-4gb"
        case basic_4vCPU_8gb = "db-s-4vcpu-8gb"
        case basic_6vCPU_16gb = "db-s-6vcpu-16gb"
        case basic_8vCPU_32gb = "db-s-8vcpu-32gb"
        case basic_16vCPU_64gb = "db-s-16vcpu-64gb"
    }
}

extension DigitalOcean.DatabaseCluster {
    public struct MaintenanceWindow: Sendable {
        public enum Day: String, Sendable {
            case monday
            case tuesday
            case wednesday
            case thursday
            case friday
            case saturday
            case sunday
        }

        public let day: Day
        public let hour: String

        public init(day: Day, hour: String) {
            self.day = day
            self.hour = hour
        }
    }
}
