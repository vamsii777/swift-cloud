import CloudCore

extension DigitalOcean {
    public struct Database: DigitalOceanComponent {
        public let cluster: DatabaseCluster

        public var name: Output<String> {
            cluster.name
        }

        public var hostname: Output<String> {
            cluster.hostname
        }

        public var privateHostname: Output<String> {
            cluster.privateHostname
        }

        public var port: Output<String> {
            cluster.port
        }

        public var user: Output<String> {
            cluster.user
        }

        public var password: Output<String> {
            cluster.password
        }

        public var database: Output<String> {
            cluster.database
        }

        public var uri: Output<String> {
            cluster.uri
        }

        public var privateUri: Output<String> {
            cluster.privateUri
        }

        public init(
            _ name: String,
            engine: DatabaseCluster.Engine,
            size: DatabaseCluster.Size = .basic_1vCPU_1gb,
            region: Region = .nyc3,
            nodeCount: Int = 1,
            projectId: Output<String>? = nil,
            tags: [String] = [],
            maintenanceWindow: DatabaseCluster.MaintenanceWindow? = nil,
            options: Resource.Options? = nil,
            context: Context = .current
        ) {
            self.cluster = DatabaseCluster(
                name,
                engine: engine,
                size: size,
                region: region,
                nodeCount: nodeCount,
                projectId: projectId,
                tags: tags,
                maintenanceWindow: maintenanceWindow,
                options: options,
                context: context
            )
        }
    }
}

extension DigitalOcean.Database: Linkable {
    public var actions: [String] {
        ["*"]
    }

    public var resources: [Output<String>] {
        [cluster.resource.id]
    }

    public var properties: LinkProperties? {
        return .init(
            type: "database",
            name: cluster.resource.chosenName,
            properties: [
                "hostname": hostname,
                "privateHostname": privateHostname,
                "port": port,
                "user": user,
                "password": password,
                "database": database,
                "uri": uri,
                "privateUri": privateUri,
            ]
        )
    }
}
