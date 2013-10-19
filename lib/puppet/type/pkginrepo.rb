Puppet::Type.newtype(:pkginrepo) do
  @doc = "ParsedFile type to handle pkgin repositories"

  ensurable

  newparam(:url) do
    desc "Repository url"
    isnamevar
  end

  newproperty(:target) do
    defaultto {
      if @resource.class.defaultprovider.ancestors.include? (Puppet::Provider::ParsedFile)
        @resouce.class.defaultprovider.default_target
      else
        nil
      end
    }
  end

end
