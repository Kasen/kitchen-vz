# Kitchen::Vz

A Virtuozzo driver for Test Kitchen

## Requirements

This driver tested only on Virtuozzo 7.

## Installation and Setup

## Installation and Setup

Please read the Test Kitchen [docs](http://kitchen.ci/docs/getting-started/) for more details.

Example `.kitchen.local.yml`:

```yaml
---
  driver:
    name: vz

  platforms:
    - name: centos-7
    driver:
      socket: ssh://user@virtuozzo.domain.loc
  suites:
    - name: default
```

## Configuration

|Attribute|Description|Default value|
|---------|-----------|-------------|
|:socket|Connection string to virtuozzo server. Supports ssh uri or `local`. `local` means what `prlctl` and `vzctl` will be started locally.|'local'|
|:username|User with this name will be created in virtuozzo container. Test kitchen uses this user to connect to the container.|'kitchen'|
|:arch|Container architecture. This attribute shows how architecture container will be created.|'x86_64'|
|:network|Hash with network configuration. See section Network configuration.|'Bridged' => {dhcp: true}|
|:customize|Hash with container settings. It may contain :memory, :disk and :cpus options.|memory: '512M', disk: '10G', cpus: 2|
|:private_key|Path to private key. This key pair used by the kitchen to login into container.|.kitchen/kitchen_id_rsa|
|:public_key|Path to public key. This key pair used by the kitchen to login into container.|.kitchen/kitchen_id_rsa.pub|
|:ostemplate|Virtuozzo template which will be used for container creating.||
|:use_sudo|It shows will sudo be used or not.|true|
|:ct_hostname|Container hostname.|It is formed from platform name and suite name.|

### Network configuration

Example of network settings:

```ruby
{
  'Bridged' => {
    dhcp: true
  },
  'Host-Only' => {
    ip: '192.168.75.1/24'
  },
  'PUB' => {
    ip: '10.10.10.20/24'
    gw: '10.10.10.1'
  }
}
```

The key of hash is a name of Virtuozzo network. Container interface will be bridged with this network. Value is a hash, which may contains next keys:
* dhcp - If this parameter is true, then network settings will be get from dhcp server.
* ip - IP-address which will be set to container. The address must be specified with the mask. Ex: 192.168.5.3/24
* gw - Gateway which will be set to container.

## Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

Created and maintained by [Pavel Yudin][author] (<pyudin@parallels.com>)

## License

Apache 2.0 (see [LICENSE][license])


[author]:           https://github.com/Kasen
[issues]:           https://github.com/Kasen/kitchen-vz/issues
[license]:          https://github.com/Kasen/kitchen-vz/blob/master/LICENSE
[repo]:             https://github.com/Kasen/kitchen-vz
