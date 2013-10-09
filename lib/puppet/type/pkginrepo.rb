Puppet::Type.newtype(:pkginrepo) do
  @doc = "Tipo para pkgin repositories"

  ensurable

newparam(:url) do
  desc "url for repository"
  isnamevar
  end

end
