#
# Cookbook Name:: grafana
# Recipe:: default
#
# Copyright 2014, Jonathan Tron
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
#

include_recipe "git"

unless Chef::Config[:solo]
  es_server_results = search(:node, "roles:#{node['grafana']['es_role']} AND chef_environment:#{node.chef_environment}")
  unless es_server_results.empty?
    node.set['grafana']['es_server'] = es_server_results[0]['ipaddress']
  end
  graphite_server_results = search(:node, "roles:#{node['grafana']['graphite_role']} AND chef_environment:#{node.chef_environment}")
  unless graphite_server_results.empty?
    node.set['grafana']['graphite_server'] = graphite_server_results[0]['ipaddress']
  end
end

if node['grafana']['user'].empty?
  unless node['grafana']['webserver'].empty?
    webserver = node['grafana']['webserver']
    grafana_user = node[webserver]['user']
  else
    grafana_user = "nobody"
  end
else
  grafana_user = node['grafana']['user']
end

directory node['grafana']['install_dir'] do
  owner grafana_user
  mode "0755"
end

case  node['grafana']['install_type']
  when "git"
    git "#{node['grafana']['install_dir']}/#{node['grafana']['git']['branch']}" do
      repository node['grafana']['git']['url']
      reference node['grafana']['git']['branch']
      case  node['grafana']['git']['type']
        when "checkout"
          action :checkout
        when "sync"
          action :sync
      end
      user grafana_user
    end
    link "#{node['grafana']['install_dir']}/current" do
      to "#{node['grafana']['install_dir']}/#{node['grafana']['git']['branch']}"
    end
    node.set['grafana']['web_dir'] = "#{node['grafana']['install_dir']}/current/src"
  when "file"
    case node['grafana']['file']['type']
      when "zip"
        include_recipe 'ark::default'
        ark 'grafana' do
          url node['grafana']['file']['url']
          path node['grafana']['install_path']
          checksum  node['grafana']['file']['checksum']
          owner grafana_user
          strip_leading_dir false
          action :put
        end
        node.set['grafana']['web_dir'] = node['grafana']['install_dir']
    end
end

template "#{node['grafana']['web_dir']}/config.js" do
  source node['grafana']['config_template']
  cookbook node['grafana']['config_cookbook']
  mode "0750"
  user grafana_user
end

unless node['grafana']['webserver'].empty?
  include_recipe "grafana::#{node['grafana']['webserver']}"
end
