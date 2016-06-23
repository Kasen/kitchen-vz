# -*- encoding: utf-8 -*-
#
# Author:: Pavel Yudin (<pyudin@parallels.com>)
#
# Copyright (C) 2016, Pavel Yudin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'
require 'securerandom'
require 'uri'
require 'net/ssh'

module Kitchen
  module Driver

    # Virtuozzo driver for Kitchen.
    #
    # @author Pavel Yudin <pyudin@parallels.com>
    class Vz < Kitchen::Driver::SSHBase

      default_config :socket, 'local'
      default_config :username, 'kitchen'
      default_config :private_key, File.join(Dir.pwd, '.kitchen', 'kitchen_id_rsa')
      default_config :public_key, File.join(Dir.pwd, '.kitchen', 'kitchen_id_rsa.pub')
      default_config :network, 'Bridged' => { dhcp: true }
      default_config :use_sudo, true
      default_config :arch, 'x86_64'
      default_config :customize, memory: '512M', disk: '10G', cpus: 2
      default_config :ostemplate, nil
      default_config :ct_hostname do |driver|
        driver.instance.name
      end

      def create(state)
        state[:ct_id] = SecureRandom.uuid
        generate_keys
        state[:ssh_key] = config[:ssh_key] = config[:private_key]
        create_ct(state)
        set_ct_network(state)
        set_ct_cpu(state)
        set_ct_mem(state)
        set_ct_disk(state)
        run_ct(state)
        create_user(state)
        state[:hostname] = ct_ip(state)
        wait_for_sshd(state[:hostname], nil, keys: [state[:ssh_key]])
      end

      def destroy(state)
        execute_command("#{prlctl} stop #{state[:ct_id]}") if state[:ct_id]
        execute_command("#{prlctl} destroy #{state[:ct_id]}") if state[:ct_id]
      end

      private

      def prlctl
        '/usr/bin/prlctl'
      end

      def vzctl
        '/usr/sbin/vzctl'
      end

      def generate_keys
        if !File.exist?(config[:public_key]) || !File.exist?(config[:private_key])
          private_key = OpenSSL::PKey::RSA.new(2048)
          blobbed_key = Base64.encode64(private_key.to_blob).gsub("\n", '')
          public_key = "ssh-rsa #{blobbed_key} kitchen_key"
          File.open(config[:private_key], 'w') do |file|
            file.write(private_key)
            file.chmod(0600)
          end
          File.open(config[:public_key], 'w') do |file|
            file.write(public_key)
            file.chmod(0600)
          end
        end
      end

      def create_ct(state)
        command_line = "#{vzctl} create #{state[:ct_id]} --hostname #{config[:ct_hostname]} --ostemplate "
        command_line += config[:ostemplate] || "#{platform_major}-#{config[:arch]}"
        execute_command(command_line)
      end

      def set_ct_network(state)
        iface_number = 0
        config[:network].each do |network, _settings|
          execute_command("#{vzctl} set #{state[:ct_id]} --netif_add eth#{iface_number} --save")
          command_line = "#{vzctl} set #{state[:ct_id]} --network #{network} --ifname eth#{iface_number} "
          command_line += '--dhcp yes ' if config[:network][network][:dhcp]
          command_line += "--ipadd #{config[:network][network][:ip]} " if config[:network][network][:ip]
          command_line += "--gw #{config[:network][network][:gw]} " if config[:network][network][:gw]
          command_line += '--save'
          execute_command(command_line)
          iface_number += 1
        end
        execute_command("#{prlctl} set #{state[:ct_id]} --netfilter full")
      end

      def set_ct_cpu(state)
        execute_command("#{prlctl} set #{state[:ct_id]} --cpus #{config[:customize][:cpus]}")
      end

      def set_ct_mem(state)
        execute_command("#{prlctl} set #{state[:ct_id]} --memsize #{config[:customize][:memory]}")
      end

      def set_ct_disk(state)
        ds = config[:customize][:disk]
        execute_command("#{vzctl} set #{state[:ct_id]} --diskspace #{ds}:#{ds} --save")
      end

      def run_ct(state)
        execute_command("#{prlctl} start #{state[:ct_id]}")
      end

      def create_user(state)
        ["useradd #{config[:username]}",
         "mkdir /home/#{config[:username]}/.ssh",
         "chown #{config[:username]}: /home/#{config[:username]}/.ssh",
         "chmod 700 /home/#{config[:username]}/.ssh",
         "echo '#{File.open(config[:public_key]).read}' > /home/#{config[:username]}/.ssh/authorized_keys",
         "chown #{config[:username]}: /home/#{config[:username]}/.ssh/authorized_keys",
         "chmod 600 /home/#{config[:username]}/.ssh/authorized_keys",
         'mkdir -p /etc/sudoers.d',
         "echo '#{config[:username]} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/#{config[:username]}",
         "chmod 0440 /etc/sudoers.d/#{config[:username]}"].each do |command|
           execute_command("#{prlctl} exec #{state[:ct_id]} \"#{command}\"")
         end
      end

      def ct_ip(state)
        ip = nil
        1..30.times do
          output = execute_command("#{vzctl} exec #{state[:ct_id]} \"/sbin/ip -o -f inet addr show dev eth0\"")
          result = %r{(([0-9]{1,3}\.){3}[0-9]{1,3})\/[0-9]{1,2}}.match(output)
          ip = result[1] if result
          break if ip
          sleep(1)
        end
        raise "Can't detect an IP!" if !ip
        ip
      end

      def platform_major
        instance.platform.name.split('.')[0]
      end

      def execute_command(command)
        if config[:socket] == 'local'
          run_command(command)
        else
          command = 'sudo -E ' + command if config[:use_sudo]
          channel = ssh_connection.open_channel do |ch|
            ch.exec(command) do |_ch, _success|
              channel[:data] = ''
              channel[:ext_data] = ''

              channel.on_data do |_ch, data|
                channel[:data] << data
              end

              channel.on_extended_data do |_ch, _type, data|
                channel[:ext_data] << data
              end

              channel.on_request 'exit-status' do |_ch, data|
                if data.read_long.to_i != 0
                  raise "SSH command failed with: #{channel[:ext_data]}"
                else
                  puts channel[:data] unless channel[:data].empty?
                end
              end
            end
            ch.wait
          end
          channel.wait
          channel[:data]
        end
      end

      def uri
        uri = URI(config[:socket])
        raise "Invalid URI scheme: #{uri.scheme}. Only 'ssh' is supported." if uri.scheme != 'ssh'
        uri
      end

      def ssh_connection
        @connection ||= Net::SSH.start(uri.host, uri.user, port: uri.port)
      end
    end
  end
end
