action :create do

	# create group and user
	group new_resource.group do
		action [ :create, :manage ]
	end.run_action(:create)

	user new_resource.user do
		comment "Scout Agent"
		gid new_resource.group
		home "/home/#{new_resource.user}"
		supports :manage_home => true
		action [ :create, :manage ]
		only_if do new_resource.user != 'root' end
	end.run_action(:create)

	# install scout agent gem
	gem_package "scout" do
		version new_resource.version
		action :upgrade
		source "http://rubygems.org/"
	end

	if new_resource.key
		scout_bin = new_resource.bin ? new_resource.bin : "#{Gem.bindir}/scout"
		name_attr = new_resource.name ? %{ --name "#{new_resource.name}"} : ""
		hostname_attr = new_resource.hostname ? %{ --hostname "#{new_resource.hostname}"} : ""
		roles_attr = new_resource.roles ? %{ --roles "#{new_resource.roles.map(&:to_s).join(',')}"} : ""
		http_proxy_attr = new_resource.http_proxy ? %{ --http-proxy "#{new_resource.http_proxy}"} : ""
		https_proxy_attr = new_resource.https_proxy ? %{ --https-proxy "#{new_resource.https_proxy}"} : ""
		environment_attr = new_resource.environment ? %{ --environment "#{new_resource.environment}"} : ""

		# schedule scout agent to run via cron. We do not start monitoring until the uptime on the machine is at leat 5 minutes
		if new_resource.crontab_action
			cron "scout_run" do
				user new_resource.user
				command "if [ `cut -d. -f1 /proc/uptime` -gt 300 ]; then #{scout_bin} #{new_resource.key}#{name_attr}#{hostname_attr}#{roles_attr}#{http_proxy_attr}#{https_proxy_attr}#{environment_attr}; fi"

				action new_resource.crontab_action

				only_if do FileTest::exist?(scout_bin) end
			end
		end

		template "/etc/init.d/scout_shutdown" do
			cookbook "scout"
			source "scout_shutdown.erb"
			owner "root"
			group "root"
			variables user: new_resource.user,
			          key: new_resource.key,
								hostname: new_resource.hostname
			mode 0755
		end

		case node["platform"]
		when "debian", "ubuntu"
			if new_resource.delete_on_shutdown
				service "scout_shutdown" do
					action [:enable, :start]
				end
			else
				service "scout_shutdown" do
					action :disable
				end
			end
		when "redhat", "centos", "fedora"
			# the service provider stuff for centos is pretty broken. We need to use --add to set up both K and S links
			if new_resource.delete_on_shutdown
				execute "chkconfig --del scout_shutdown && chkconfig --add scout_shutdown && /etc/init.d/scout_shutdown start"
			else
				execute "chkconfig --del scout_shutdown"
			end
		end
	else
		Chef::Log.warn "The agent will not report to scoutapp.com as a key wasn't provided. Provide a [:scout][:key] attribute to complete the install."
	end

	if new_resource.public_key
		home_dir = Dir.respond_to?(:home) ? Dir.home(new_resource.user) : File.expand_path("~#{new_resource.user}")
		data_dir = "#{home_dir}/.scout"
		# create the .scout directory
		directory data_dir do
			group new_resource.group
			owner new_resource.user
			mode "0755"
		end
		template "#{data_dir}/scout_rsa.pub" do
			cookbook "scout"
			source "scout_rsa.pub.erb"
			mode 0440
			owner new_resource.user
			group new_resource.group
			variables public_key: new_resource.public_key
			action :create
		end
	end

	# this was the old location installed by this script
	file "/etc/rc0.d/scout_shutdown" do
		action :delete
	end

	(new_resource.plugin_gems || []).each do |gemname|
		gem_package gemname
	end
end
