# eslco: 配置 DNS 服务器

在 Debian 12 系统中，DNS 配置需要修改 `/etc/resolv.conf` 文件。您可以按照以下步骤进行设置：

## 编辑 `/etc/resolv.conf` 文件

使用文本编辑器（例如 nano 或 vim）打开 `/etc/resolv.conf` 文件：

```sh
sudo nano /etc/resolv.conf
```

## 添加 DNS 服务器

在文件中，添加以下内容，其中 `DNS_IP` 为您刚刚从平台上复制的 DNS IP 地址：

```plaintext
nameserver DNS_IP
nameserver 1.1.1.1
```

例如，如果复制的 DNS IP 地址是 `103.2.57.5`，那么您应该看到：

```plaintext
nameserver 103.2.57.5
nameserver 1.1.1.1
```

## 保存并退出

按下 `Ctrl + O` 保存修改，然后按下 `Ctrl + X` 退出编辑器。

> 注意： 如果您的系统使用 DHCP，`/etc/resolv.conf` 文件可能会被自动覆盖。建议您在这种情况下使用其他更持久的方式来配置 DNS，例如通过 `netplan` 或 `systemd-resolved` 进行配置。

## 使用 `netplan` 或 `systemd-resolved` 防止 `/etc/resolv.conf` 被自动覆盖

在 Debian 12 系统中，您可以使用 `netplan` 或 `systemd-resolved` 来配置 DNS 服务器，并防止 `/etc/resolv.conf` 被自动覆盖。以下是这两种方法的详细步骤：

### 使用 Netplan 配置 DNS

1. 编辑 Netplan 配置文件：

   ```sh
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

2. 添加或修改 DNS 配置。例如：

   ```yaml
   network:
     version: 2
     ethernets:
       eth0:
         dhcp4: true
         nameservers:
           addresses:
             - 1.0.0.1
             - 8.8.4.4
   ```

3. 应用 Netplan 配置：

   ```sh
   sudo netplan apply
   ```

### 使用 systemd-resolved 配置 DNS

1. 编辑 `resolved.conf` 文件：

   ```sh
   sudo nano /etc/systemd/resolved.conf
   ```

2. 添加或修改 DNS 配置。例如：

   ```ini
   [Resolve]
   DNS=1.0.0.1 8.8.4.4
   ```

3. 重新启动 `systemd-resolved` 服务：

   ```sh
   sudo systemctl restart systemd-resolved
   ```

4. 确保 `/etc/resolv.conf` 是指向 `systemd-resolved` 的符号链接：

   ```sh
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   ```

### 其他方法

如果您不想使用 Netplan 或 systemd-resolved，还可以考虑以下方法：

1. **使用 chattr 命令锁定 `/etc/resolv.conf` 文件**：

   ```sh
   sudo chattr +i /etc/resolv.conf
   ```

   这将使文件变为不可变，防止任何进程修改它。要取消锁定，可以使用：

   ```sh
   sudo chattr -i /etc/resolv.conf
   ```

2. **编辑 DHCP 客户端配置**：

   如果您使用的是 `dhclient`，可以编辑 `/etc/dhcp/dhclient.conf` 文件，添加以下行来防止 DHCP 客户端修改 `/etc/resolv.conf`：

   ```ini
   supersede domain-name-servers 1.0.0.1, 8.8.4.4;
   ```

这些方法可以帮助您防止 `/etc/resolv.conf` 文件被自动覆盖，并确保您的 DNS 配置持久有效。

## 更多配置示例

### 使用 Netplan 配置 DNS

假设您的网络接口名称是 `eth0`，并且您希望配置静态 IP 和 DNS 服务器：

1. 编辑 Netplan 配置文件：

   ```sh
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

2. 添加或修改配置，例如：

   ```yaml
   network:
     version: 2
     ethernets:
       eth0:
         addresses:
           - 192.168.1.100/24
         gateway4: 192.168.1.1
         nameservers:
           addresses:
             - 1.0.0.1
             - 8.8.4.4
   ```

3. 应用 Netplan 配置：

   ```sh
   sudo netplan apply
   ```

### 使用 systemd-resolved 配置 DNS

1. 编辑 `resolved.conf` 文件：

   ```sh
   sudo nano /etc/systemd/resolved.conf
   ```

2. 添加或修改配置，例如：

   ```ini
   [Resolve]
   DNS=1.0.0.1 8.8.4.4
   FallbackDNS=2606:4700:4700::1001 2001:4860:4860::8844
   ```

3. 重新启动 `systemd-resolved` 服务：

   ```sh
   sudo systemctl restart systemd-resolved
   ```

4. 确保 `/etc/resolv.conf` 是指向 `systemd-resolved` 的符号链接：

   ```sh
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   ```

### 使用 DHCP 客户端配置 DNS

如果您使用的是 `dhclient`，可以编辑 `/etc/dhcp/dhclient.conf` 文件来配置 DNS：

1. 编辑 `dhclient.conf` 文件：

   ```sh
   sudo nano /etc/dhcp/dhclient.conf
   ```

2. 添加或修改配置，例如：

   ```ini
   supersede domain-name-servers 1.0.0.1, 8.8.4.4;
   ```

3. 重新启动网络接口：

   ```sh
   sudo ifdown eth0 && sudo ifup eth0
   ```

### 使用 chattr 命令锁定 `/etc/resolv.conf`

1. 编辑 `/etc/resolv.conf` 文件，添加您的 DNS 服务器：

   ```sh
   sudo nano /etc/resolv.conf
   ```

2. 添加 DNS 服务器，例如：

   ```plaintext
   nameserver 1.0.0.1
   nameserver 8.8.4.4
   ```

3. 锁定 `/etc/resolv.conf` 文件：

   ```sh
   sudo chattr +i /etc/resolv.conf
   ```

这些示例应该能够帮助您在不同情况下配置 DNS 并防止 `/etc/resolv.conf` 被自动覆盖。

## 其他有效且适合新手操作的 DNS 配置方案

### 使用 `systemd-resolved` 配置 DNS

1. 编辑 `resolved.conf` 文件：

   ```sh
   sudo nano /etc/systemd/resolved.conf
   ```

2. 在文件中添加或修改 DNS 配置：

   ```ini
   [Resolve]
   DNS=1.0.0.1 8.8.4.4 2606:4700:4700::1001 2001:4860:4860::8844
   FallbackDNS=8.8.8.8 8.8.4.4
   ```

3. 重新启动 `systemd-resolved` 服务：

   ```sh
   sudo systemctl restart systemd-resolved
   ```

4. 确保 `/etc/resolv.conf` 是指向 `systemd-resolved` 的符号链接：

   ```sh
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   ```

### 使用 NetworkManager 配置 DNS

1. 编辑 NetworkManager 配置文件：

   ```sh
   sudo nano /etc/NetworkManager/NetworkManager.conf
   ```

2. 在 `[main]` 部分添加或修改以下行：

   ```ini
   [main]
   dns=none
   ```

3. 编辑网络连接配置文件：

   ```sh
   sudo nano /etc/NetworkManager/system-connections/your-connection-name
   ```

4. 在 `[ipv4]` 和 `[ipv6]` 部分添加或修改 DNS 配置：

   ```ini
   [ipv4]
   method=auto
   dns=1.0.0.1;8.8.4.4;
   ignore-auto-dns=true

   [ipv6]
   method=auto
   dns=2606:4700:4700::1001;2001:4860:4860::8844;
   ignore-auto-dns=true
   ```

5. 重新启动 NetworkManager：

   ```sh
   sudo systemctl restart NetworkManager
   ```

### 使用 `dhclient` 配置 DNS

1. 编辑 `dhclient.conf` 文件：

   ```sh
   sudo nano /etc/dhcp/dhclient.conf
   ```

2. 添加或修改以下行：

   ```ini
   supersede domain-name-servers 1.0.0.1, 8.8.4.4, 2606:4700:4700::1001, 2001:4860:4860::8844;
   ```

3. 重新启动网络接口：

   ```sh
   sudo ifdown eth0 && sudo ifup eth0
   ```

### 使用 `chattr` 命令锁定 `/etc/resolv.conf`

1. 编辑 `/etc/resolv.conf` 文件，添加您的 DNS 服务器：

   ```sh
   sudo nano /etc/resolv.conf
   ```

2. 在文件中添加以下内容：

   ```plaintext
   nameserver 1.0.0.1
   nameserver 8.8.4.4
   nameserver 2606:4700:4700::1001
   nameserver 2001:4860:4860::8844
   ```

3. 锁定 `/etc/resolv.conf` 文件：

   ```sh
   sudo chattr +i /etc/resolv.conf
   ```

这些方法应该能够帮助用户在不同情况下配置 DNS 并防止 `/etc/resolv.conf` 文件被自动覆盖。选择适合用户的方案进行操作即可。
