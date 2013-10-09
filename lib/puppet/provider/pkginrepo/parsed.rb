
require 'puppet/provider/parsedfile'

Puppet::Type.type(:pkginrepo).provide(:parsed, :parent => Puppet::Provider::ParsedFile, :filetype => :flat) do

  desc "Provider"

  text_line :comment , :match => /^#/;
  text_line :blank , :match => /^\s*$/;

  record_line :parsed , :fields => %w{url}

end
