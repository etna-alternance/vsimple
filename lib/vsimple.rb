require "rbvmomi"
require "vsimple/version"
require "vsimple/error"
require "vsimple/config"

require "vsimple/vm"

class Vsimple

    def self.connect(opts)
        Vsimple::Config[:auth] = {
            :path     => "/sdk",
            :port     => 443,
            :use_ssl  => true,
            :insecure => "USE_INSECURE_SSL"
            }
        Vsimple::Config[:auth].merge! opts
        Vsimple::Config[:vim] = RbVmomi::VIM.connect Vsimple::Config[:auth]
    end

    def self.set_dc(dcname)
        Vsimple::Config[:dc_name] = dcname
        Vsimple::Config[:dc] = Vsimple::Config[:vim].serviceInstance.find_datacenter(Vsimple::Config[:dc_name])
        raise Vsimple::Error.new "Datacenter #{dcname} not found" unless Vsimple::Config[:dc]
    end

    def self.set_cluster(c_name)
        Vsimple::Config[:cluster_name] = c_name
        Vsimple::Config[:cluster] = Vsimple::Config[:dc].hostFolder.childEntity.grep(RbVmomi::VIM::ClusterComputeResource).find { |x| x.name == Vsimple::Config[:cluster_name] }
        raise Vsimple::Error.new "Cluster #{Config[:c_name]} not found" unless Vsimple::Config[:cluster]
    end

end
