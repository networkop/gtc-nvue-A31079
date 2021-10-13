# gtc-nvue-A31079

This repository contains source code and instructions to accompany the NVIDIA GTC talk "Innovations in NVIDIA Networking Management [A31079]"

Use the topology.{dot,svg} files to create a custom topology in air.nvidia.com:

1. Click "Create a Simulation".
2. Select "Build Your Own".
3. Select "Upload a topology file".
4. Drag and drop that `topology.dot` file .
5. Expand the `Advanced` section and click `Apply Template` to generate a ZTP script.

![](./topology.svg)


## How to use VS Code

This section explains how to use VS Code to connect to virtual devices in Air.

1. (Optional) Before you start the topology, upload your public SSH key into https://air.nvidia.com/settings/ssh-keys.
2. From the `Advanced` view of the simulation topology click `Enable SSH`.
3. Log into the `oob-mgmt-server` manually to reset the password.
3. Make sure that the SSH plugin is installed in VS Code and open the Command Palette (Ctrl+Shift+P).
4. Select `Remote SSH`, followed by `Configure SSH Hosts...`.
5. Enter the following details, adjusted based on the SSH host and port details from step #2.


```
Host spine
  User cumulus
  HostName spine
  ProxyJump  cumulus@worker03.air.nvidia.com:10665
  StrictHostKeyChecking no
  ForwardAgent yes
  UserKnownHostsFile /dev/null

Host oob
  User cumulus
  HostName worker03.air.nvidia.com
  Port 10665
  StrictHostKeyChecking no
  ForwardAgent yes
  UserKnownHostsFile /dev/null
```

6. Now you can connect to either `oob-mgmt-server` or `spine` switch and use VSCode's terminal console will have SSH agent with your private SSH key.