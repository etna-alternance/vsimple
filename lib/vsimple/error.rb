class Vsimple
    class Error < RuntimeError

        attr :msg

        def initialize(msg)
            @msg = msg
        end

    end
end
