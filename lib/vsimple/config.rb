require 'mixlib/config'

class Vsimple
    class Config

        extend Mixlib::Config

        def self.inspect
            configuration.inspect
        end

    end
end
