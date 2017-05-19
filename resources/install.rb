# resources/install.rb
#
# Cookbook Name:: telegraf
# Resource:: install
#
# Copyright 2015-2016 NorthPage
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

property :include_repository, [TrueClass, FalseClass], default: true
property :name, String, name_property: true
property :install_version, [String, nil], default: nil
property :install_type, String, default: 'package'

default_action :create

action :create do
  chef_gem 'toml' do
    version node['telegraf']['toml_gem_version']
  end

  case install_type
  when 'package'
    if platform_family? 'rhel'
      yum_repository 'telegraf' do
        description 'InfluxDB Repository - RHEL \$releasever'
        case node['platform']
        when 'redhat'
          baseurl 'https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable'
        when 'amazon'
          baseurl 'https://repos.influxdata.com/centos/7/\$basearch/stable'
        else
          baseurl 'https://repos.influxdata.com/centos/\$releasever/\$basearch/stable'
        end
        gpgkey 'https://repos.influxdata.com/influxdb.key'
        only_if { include_repository }
      end
    elsif node.platform_family? 'debian'
      package 'apt-transport-https' do
        only_if { include_repository }
      end

      apt_repository 'influxdb' do
        uri "https://repos.influxdata.com/#{node['platform']}"
        distribution node['lsb']['codename']
        components ['stable']
        arch 'amd64'
        key 'https://repos.influxdata.com/influxdb.key'
        only_if { include_repository }
      end
    else    
      raise "I do not support your platform: #{node['platform_family']}"
    end

    package 'telegraf' do
      version install_version
    end
  when 'tarball'
    # TODO: implement me
    Chef::Log.warn('Sorry, installing from a tarball is not yet implemented.')
  
  when 'file'
    if node.platform_family? 'rhel'
      file_name = "telegraf-#{install_version}.x86_64.rpm"
      remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
        source "#{node['telegraf']['download_urls']['rhel']}/#{file_name}"
        checksum node['telegraf']['shasums']['rhel']
        action :create
      end

      rpm_package 'telegraf' do
        source "#{Chef::Config[:file_cache_path]}/#{file_name}"
        action :install
      end
    elsif node.platform_family? 'debian'
      # NOTE: file_name would be influxdb_<version> instead.
      file_name = "telegraf_#{install_version}_amd64.deb"
      remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
        source "#{node['telegraf']['download_urls']['debian']}/#{file_name}"
        checksum node['telegraf']['shasums']['debian']
        action :create
      end

      dpkg_package 'telegraf' do
        source "#{Chef::Config[:file_cache_path]}/#{file_name}"
        options '--force-confdef --force-confold'
        action :install
      end
    else
      raise "I do not support your platform: #{node['platform_family']}"
    end
  else
    raise "#{install_type} is not a valid install type."
  end

  service "telegraf_#{name}" do
    service_name 'telegraf'
    action [:enable, :start]
  end
end

action :delete do
  service "telegraf_#{name}" do
    service_name 'telegraf'
    action [:stop, :disable]
  end

  package 'telegraf' do
    action :remove
  end
end
