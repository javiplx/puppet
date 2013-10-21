
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'

require 'puppet_spec/files'

provider_class = Puppet::Type.type(:pkgsrcrepo).provider(:parsed)

describe provider_class do

  it_should_behave_like "all parsedfile providers",
    provider_class , my_fixtures('*.conf')

end

