
actions :create

attribute :key,           :kind_of => String, :required => true
attribute :user,          :kind_of => String, :default => "scout"
attribute :group,         :kind_of => String, :default => "scout"
attribute :name,          :kind_of => [String, NilClass]
attribute :hostname,      :kind_of => [String, NilClass]
attribute :roles,         :kind_of => [Array, NilClass]
attribute :bin,           :kind_of => [String, NilClass]
attribute :version,       :kind_of => [String, NilClass]
attribute :public_key,    :kind_of => [String, NilClass]
attribute :http_proxy,    :kind_of => [String, NilClass]
attribute :https_proxy,   :kind_of => [String, NilClass]
attribute :delete_on_shutdown,   :kind_of => [TrueClass, FalseClass], :default => false
attribute :plugin_gems,   :kind_of => Array, :default => []
attribute :environment,   :kind_of => [String, NilClass]
attribute :crontab_action, :kind_of => [String, Symbol, NilClass]

def initialize(*args)
  super
  @action = :create
end
