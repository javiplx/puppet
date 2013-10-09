
require 'puppet/provider/parsedfile'

repositories = "/opt/local/etc/pkgin/repositories.conf"

Puppet::Type.type(:pkginrepo).provide(:parsed, :parent => Puppet::Provider::ParsedFile, :default_target => repositories , :filetype => :flat) do

  desc "Provider"

  text_line :comment , :match => /^#/;
  text_line :blank , :match => /^\s*$/;

  record_line :parsed , :fields => %w{url}

end
