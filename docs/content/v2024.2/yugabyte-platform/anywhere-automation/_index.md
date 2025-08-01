---
title: Automation in YugabyteDB Anywhere
headerTitle: Automation
linkTitle: Automation
description: Automation tools for YugabyteDB Anywhere.
headcontent: Manage YugabyteDB Anywhere accounts and deployments using automation
menu:
  v2024.2_yugabyte-platform:
    parent: yugabytedb-anywhere
    identifier: anywhere-automation
    weight: 680
type: indexpage
showRightNav: true
---

Use the following automation tools to manage your YugabyteDB Anywhere installation and universes:

| Automation | Description |
| :--------- | :---------- |
| [REST API](anywhere-api/) | Deploy and manage database universes using a REST API. |
| [Terraform provider](anywhere-terraform/) | Provider for automating YugabyteDB Anywhere resources that are accessible via the API. |
| [CLI](anywhere-cli/) | Manage YugabyteDB Anywhere resources from the command line. {{<tags/feature/ea idea="1879">}} |
| [YugabyteDB Kubernetes Operator](yb-kubernetes-operator/) | Automate the deployment and management of YugabyteDB clusters in Kubernetes environments. {{<tags/feature/ea idea="831">}} |

### Authentication

For access, automation tools require authentication in the form of an API token.

To obtain your API token:

1. In YugabyteDB Anywhere, click the profile icon at the top right and choose **User Profile**.

1. Under **API Key management**, copy your API token. If the **API Token** field is blank, click **Generate Key**, and then copy the resulting API token.

Generating a new API token invalidates your existing token. Only the most-recently generated API token is valid.

### Account details

For some REST API commands, you may need one or more of the following account details:

- Customer ID.

    To view your customer ID, click the **Profile** icon in the top right corner of the YugabyteDB Anywhere window, and choose **User Profile**.

- Universe ID.

    Every universe has a unique ID. To obtain a universe ID in YugabyteDB Anywhere, click **Universes** in the left column, then click the name of the universe. The URL of the universe's **Overview** page ends with the universe's UUID. For example:

    ```output
    https://myPlatformServer/universes/d73833fc-0812-4a01-98f8-f4f24db76dbe
    ```
