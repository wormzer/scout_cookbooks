#
# Cookbook Name:: scout
# Recipe:: default

Chef::Log.info "Loading: #{cookbook_name}::#{recipe_name}"

case node[:platform]
when 'ubuntu'
  apt_repository "scout" do
    key "https://archive.scoutapp.com/scout-archive.key"
    uri "http://archive.scoutapp.com"
    components ["ubuntu", "main"]
  end
when 'redhat', 'centos'
  yum_repository "scout" do
    description "Scout server monitoring - scoutapp.com"
    baseurl "http://archive.scoutapp.com/rhel/$releasever/main/$basearch/"
    gpgkey "https://archive.scoutapp.com/RPM-GPG-KEY-scout"
    action :create
  end
when 'fedora'
  yum_repository "scout" do
    description "Scout server monitoring - scoutapp.com"
    baseurl "http://archive.scoutapp.com/fedora/$releasever/main/$basearch/"
    gpgkey "https://archive.scoutapp.com/RPM-GPG-KEY-scout"
    action :create
  end
end

service "scout" do
  action :nothing
  supports :restart => true
  restart_command "scoutctl restart"
end

# stop scoutd out of the box. Scout will start with its own upstart config
package "scoutd" do
  action :install
  version node[:scout][:version]
  notifies :stop, "service[scout]", :immediately
  notifies :delete, "template[/etc/init/scout.conf]", :immediately
end

if node[:scout][:account_key]
  ENV['SCOUT_KEY'] = node[:scout][:account_key]

  template "/etc/scout/scoutd.yml" do
    source "scoutd.yml.erb"
    owner "scoutd"
    group "scoutd"
    variables :options => {
      :account_key => node[:scout][:account_key],
      :hostname => node[:scout][:hostname],
      :display_name => node[:scout][:display_name],
      :log_file => node[:scout][:log_file],
      :ruby_path => node[:scout][:ruby_path],
      :environment => node[:scout][:environment],
      :roles => node[:scout][:roles],
      :agent_data_file => node[:scout][:agent_data_file],
      :http_proxy => node[:scout][:http_proxy],
      :https_proxy => node[:scout][:https_proxy]
    }
    action :create
    notifies(:restart, "service[scout]", :delayed) if File.exist?('/etc/init/scout.conf')
  end
else
  Chef::Log.warn "The agent will not report to scoutapp.com as a key wasn't provided. Provide a [:scout][:account_key] attribute to complete the install."
  cookbook_file "/etc/scout/scoutd.yml" do
    action :delete
  end
end

directory "/var/lib/scoutd/.scout" do
  owner "scoutd"
  group "scoutd"
  recursive true
end

if node[:scout][:public_key]
  template "/var/lib/scoutd/.scout/scout_rsa.pub" do
    source "scout_rsa.pub.erb"
    mode 0440
    owner "scoutd"
    group "scoutd"
    action :create
  end
end

if node[:scout][:action].nil?
  scout_action = []
elsif node[:scout][:action].is_a?(Symbol)
  scout_action = [ node[:scout][:action] ]
else
  scout_action = node[:scout][:action]
end

# stop scout on action [:stop]
ruby_block "service stopper" do
  block {}
  notifies :stop, "service[scout]", :immediately
  only_if { scout_action.include?(:stop) }
end

template "/etc/init/scout.conf" do
  source "init_scout.erb"
  owner "root"
  group "root"
  variables delete_on_shutdown: node[:scout][:delete_on_shutdown],
            hostname: node[:scout][:hostname] || `hostname`

  action (if scout_action.include?(:enable)
           :create
         elsif scout_action.include?(:disable)
           :delete
         end)
end

(node[:scout][:plugin_gems] || []).each do |gemname|
  Scout.install_gem(node, [gemname])
end

# Create plugin lookup properties
template "/var/lib/scoutd/.scout/plugins.properties" do
  source "plugins.properties.erb"
  mode 0664
  owner "scoutd"
  group "scoutd"
  variables plugin_properties: node['scout']['plugin_properties']
  action :create
end

# stop scout on action [:start]
ruby_block "service starter" do
  block {}
  notifies :start, "service[scout]", :delayed
  only_if { scout_action.include?(:start) && File.exist?('/etc/init/scout.conf') }
end

#  vim: set ts=2 sw=2 tw=0 softtabstop=2 et :
