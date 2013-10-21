
require 'puppet/provider/parsedfile'

case Facter.value(:operatingsystem) when "SmartOS"
  repositories = "/opt/local/etc/pkgin/repositories.conf"
else
  repositories = "/etc/pkgin/repositories.conf"
end

Puppet::Type.type(:pkgsrcrepo).provide(:parsed, :parent => Puppet::Provider::ParsedFile, :default_target => repositories , :filetype => :flat) do

  desc "Basic provider for pkgsrcrepo type"

  confine :exists => repositories

  text_line :comment , :match => /^#/;
  text_line :blank , :match => /^\s*$/;

  record_line :parsed , :fields => %w{name}

  commands :pkgin => "pkgin"

  def flush
    super
    pkgin("-yf", :update)
  end

end
