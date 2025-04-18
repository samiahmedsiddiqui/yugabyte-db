## yba provider onprem instance-type

Manage YugabyteDB Anywhere on-premises instance types

### Synopsis

Manage YugabyteDB Anywhere on-premises instance types

```
yba provider onprem instance-type [flags]
```

### Options

```
  -h, --help   help for instance-type
```

### Options inherited from parent commands

```
  -a, --apiToken string    YugabyteDB Anywhere api token.
      --config string      Full path to a specific configuration file for YBA CLI. If provided, this takes precedence over the directory specified via --directory, and the generated files are added to the same path. If not provided, the CLI will look for '.yba-cli.yaml' in the directory specified by --directory. Defaults to '$HOME/.yba-cli/.yba-cli.yaml'.
      --debug              Use debug mode, same as --logLevel debug.
      --directory string   Directory containing YBA CLI configuration and generated files. If specified, the CLI will look for a configuration file named '.yba-cli.yaml' in this directory. Defaults to '$HOME/.yba-cli/'.
      --disable-color      Disable colors in output. (default false)
  -H, --host string        YugabyteDB Anywhere Host (default "http://localhost:9000")
  -l, --logLevel string    Select the desired log level format. Allowed values: debug, info, warn, error, fatal. (default "info")
  -n, --name string        [Optional] The name of the provider for the action. Required for create, delete, describe, update, instance-type and node.
  -o, --output string      Select the desired output format. Allowed values: table, json, pretty. (default "table")
      --timeout duration   Wait command timeout, example: 5m, 1h. (default 168h0m0s)
      --wait               Wait until the task is completed, otherwise it will exit immediately. (default true)
```

### SEE ALSO

* [yba provider onprem](yba_provider_onprem.md)	 - Manage a YugabyteDB Anywhere on-premises provider
* [yba provider onprem instance-type add](yba_provider_onprem_instance-type_add.md)	 - Add an instance type to YugabyteDB Anywhere on-premises provider
* [yba provider onprem instance-type describe](yba_provider_onprem_instance-type_describe.md)	 - Describe instance type of a YugabyteDB Anywhere on-premises provider
* [yba provider onprem instance-type list](yba_provider_onprem_instance-type_list.md)	 - List instance types of a YugabyteDB Anywhere on-premises provider
* [yba provider onprem instance-type remove](yba_provider_onprem_instance-type_remove.md)	 - Delete instance type of a YugabyteDB Anywhere on-premises provider

