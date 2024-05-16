# Overview

Cloud-init is the industry standard multi-distribution method for cross-platform cloud instance initialisation. It is supported across all major public cloud providers, provisioning systems for private cloud infrastructure, and bare-metal installations.
During boot, cloud-init identifies the cloud it is running on and initialises the system accordingly. Cloud instances will automatically be provisioned during first boot with networking, storage, SSH keys, packages and various other system aspects already configured.
Cloud-init provides the necessary glue between launching a cloud instance and connecting to it so that it works as expected.

For cloud users, cloud-init provides no-install first-boot configuration management of a cloud instance. For cloud providers, it provides instance setup that can be integrated with your cloud.

Most PaaS providers such as Azure, GCP, AWS enables user to customize their O/S setup via cloud-init.
Follow the document [Implementing SafeSquid on Cloud](https://help.safesquid.com/portal/en/kb/articles/implementing-safesquid-on-cloud) to setup SafeSquid on such a PaaS provider using the cloud-init script. 

# Tested Platforms 
1. Microsoft Azure
2. Amazon AWS
3. Digital Ocean
