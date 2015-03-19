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

if node[:scout][:account_key]
  ENV['SCOUT_KEY'] = node[:scout][:account_key]

  package "scoutd" do
    action :install
    version node[:scout][:version]
  end

  # We only need the scout service definition so that we can
  # restart scout after we configure scoutd.yml
  service "scout" do
    action :nothing
    supports :restart => true
    restart_command "scoutctl restart"
  end

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
    notifies :restart, 'service[scout]', :delayed
  end
else
  Chef::Log.warn "The agent will not report to scoutapp.com as a key wasn't provided. Provide a [:scout][:account_key] attribute to complete the install."
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

template "/etc/init/scout.conf" do
  source "init_scout.erb"
  owner "root"
  group "root"
  variables delete_on_shutdown: node[:scout][:delete_on_shutdown],
            hostname: node[:scout][:hostname] || `hostname`
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
