#
# Cookbook Name:: scout
# Recipe:: default

Chef::Log.info "Loading: #{cookbook_name}::#{recipe_name}"

scout_agent "scout agent" do
	key node[:scout][:key]
	user node[:scout][:user]
	group node[:scout][:group]
	name node[:scout][:name]
	hostname node[:scout][:hostname]
	roles node[:scout][:roles]
	bin node[:scout][:bin]
	version node[:scout][:version]
	public_key node[:scout][:public_key]
	http_proxy node[:scout][:http_proxy]
	https_proxy node[:scout][:https_proxy]
	delete_on_shutdown node[:scout][:delete_on_shutdown]
	plugin_gems node[:scout][:plugin_gems]
	environment node[:scout][:environment]
	crontab_action node[:scout][:crontab_action]
end
