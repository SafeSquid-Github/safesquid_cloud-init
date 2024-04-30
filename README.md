# Overview

You cannot setup SafeSquid using SAB on a PaaS such as Azure that does not allow upload of custom ISO file.
You can download the SafeSquid tar-ball and use it to manually setup on a virtual guest created on such PaaS.
However, the other optimizations done by the SAB, require substantial effort, and disk partitioning remains unoptimized.
Most importantly, implementing the optimum disk partitioning recipe can be most frustrating for a first-timer.
Logs, caching objects, and various other files created in runtime by SafeSquid and other Linux applications and processes, can consume disk space, leading to performance degradation, or even application failure.
The SAB creates custom partitions using LVM, ensuring isolation of files in logical volumes, and enables easy addition of storage to extend any partition when need arises. 

Most PaaS providers such as Azure, enable users to customize their O/S setup via cloud-init. Cloud-init enables partition customization, thus mitigates our key concern. 
Follow the document [Implementing SafeSquid on Cloud](https://help.safesquid.com/portal/en/kb/articles/implementing-safesquid-on-cloud) to setup SafeSquid on such a PaaS provider using the cloud-init script. 
