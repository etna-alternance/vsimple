class Vsimple
    class VM

        def initialize(path)
            @vm = Vsimple::Config[:dc].vmFolder.traverse(path, RbVmomi::VIM::VirtualMachine)
            raise Vsimple::Error.new "VM #{path} not found" unless @vm
        end

        def name
            @vm.name
        end

        def self.exist?(path)
            if Vsimple::Config[:dc].vmFolder.traverse(path, RbVmomi::VIM::VirtualMachine)
                true
            else
                false
            end
        end

        def powerOn
            begin
                @vm.PowerOnVM_Task.wait_for_completion
            rescue => e
                raise Vsimple::Error.new "Power on vm #{@vm.name}:#{e.message}"
            end
        end

        def poweredOff
            begin
                @vm.PowerOffVM_Task.wait_for_completion
            rescue => e
                raise Vsimple::Error.new "Power off vm #{@vm.name}:#{e.message}"
            end
        end

        def shutdownGuest
            begin
                @vm.ShutdownGuest
            rescue => e
                raise Vsimple::Error.new "Shutdown vm #{@vm.name}:#{e.message}"
            end
        end

        def powerState
            @vm.summary.runtime.powerState
        end

        def rebootGuest
            begin
                @vm.RebootGuest
            rescue => e
                raise Vsimple::Error.new "RebootGuest vm #{@vm.name}:#{e.message}"
            end
        end

        def guestToolsReady?
            @vm.guest.toolsRunningStatus == "guestToolsRunning"
        end

        # Clone the VirtualMachine.
        #
        # == Parameters:
        # name::
        #    Name of the machine. Can be the FQDN.
        #
        # vm_config::
        #    machine_options:
        #    * :path     => Path of the VM
        #    * :hostname => Hostname of the VM
        #    * :domain   => Domain name of the VM
        #    * :powerOn  => Flags to start the VM after the clone (true or false)
        #    * :ip_dns   => IP separed by commate of the DNS server
        #    * :network => Network configuration. exemple:
        #        vm_config[:network] = {
        #            "Network adapter 1" => {
        #                :port_group => "port_group_name",
        #                :ip   => "172.16.1.1/24",
        #                :gw   => "172.16.1.254"
        #            }
        #        }
        #    Windows only:
        #    * :commandList
        #    * :password
        #    * :timeZone
        #    * :identification_domainAdmin
        #    * :identification_domainAdminPassword
        #    * :identification_joinDomain
        #    * :identification_joinWorkgroup
        #    * :userData_orgName
        #    * :userData_productId
        #
        def clone(name, vm_config={})
            unless vm_config[:path]
                if name.include?('/')
                    vm_config[:path] = File.dirname(name)
                else
                    vm_config[:path] = ""
                end
            end
            name = File.basename(name)

            vm_config[:hostname] ||= name[/^([^.]*)/, 1]
            vm_config[:domain]   ||= name[/^[^.]*.(.*)$/, 1]

            clone_spec  = generate_clone_spec(vm_config)
            dest_folder = Vsimple::Config[:dc].vmFolder.traverse!(vm_config[:path], RbVmomi::VIM::Folder)

            @vm.CloneVM_Task(
                :folder => dest_folder,
                :name   => name,
                :spec   => clone_spec
            ).wait_for_completion

            Vsimple::VM.new("#{vm_config[:path]}/#{name}")
        end

        # Check if the machine is a windows
        #
        # == Parameters:
        # vm::
        #     VM instance given by rbvmomi
        def is_windows?
            @vm.summary.config.guestFullName =~ /^Microsoft Windows/
        end

        # Wait until the guest tools of the machine is start or until timeout if given.
        #
        # == Parameters:
        # server::
        #     VM instance given by rbvmomi
        #
        # timeout::
        #     Timeout
        def wait_guest_tools_ready(timeout=nil)
            wait = 1
            while @vm.guest.toolsRunningStatus != "guestToolsRunning" && (!timeout || wait < timeout)
                sleep 1
                wait += 1
            end
            @vm.guest.toolsRunningStatus == "guestToolsRunning"
        end

        # Wait until the machine stop or until timeout if given
        #
        # == Parameters:
        # server::
        #     VM instance given by rbvmomi
        #
        # timeout::
        #     Timeout
        def wait_to_stop(timeout=nil)
            wait = 1
            while @vm.summary.runtime.powerState != "poweredOff" && (!timeout || wait < timeout)
                sleep 1
                wait += 1
            end
            @vm.summary.runtime.powerState == "poweredOff"
        end


        protected


        # Generate the adaptater mapping for a network card
        #
        # == Parameters:
        # ip::
        #     The ip. If not given, use the dhcp configuration
        # gw::
        #     The gateway.
        def generate_adapter_map(ip=nil, gw=nil)
            settings = RbVmomi::VIM.CustomizationIPSettings

            if ip.nil?
                settings.ip = RbVmomi::VIM::CustomizationDhcpIpGenerator
            else
                cidr_ip             = NetAddr::CIDR.create(ip)
                settings.ip         = RbVmomi::VIM::CustomizationFixedIp(:ipAddress => cidr_ip.ip)
                settings.subnetMask = cidr_ip.netmask_ext
                unless gw.nil?
                    gw_cidr          = NetAddr::CIDR.create(gw)
                    settings.gateway = [gw_cidr.ip]
                end
            end

            adapter_map         = RbVmomi::VIM.CustomizationAdapterMapping
            adapter_map.adapter = settings
            adapter_map
        end

        # Find a network with a name.
        #
        # == Parameters:
        # networkName::
        #      The network name.
        #
        # == Return Value:
        # Network instance given by rbvmomi. If the network doesn't exists, an exception will rise.
        #
        def find_network(networkName)
            baseEntity = Vsimple::Config[:dc].network
            baseEntity.find { |f| f.name == networkName } or raise Vsimple::Error.new "no such network #{networkName}"
        end

        # Generate the clone specification.
        #
        # == Parameters:
        # vm_config::
        #      The vm configuration for the new VM.
        def generate_clone_spec(vm_config)
            rp         = Vsimple::Config[:cluster].resourcePool
            rspec      = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => rp)
            vm_config[:powerOn] ||= false
            clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec({
                :location => rspec,
                :powerOn  => vm_config[:powerOn],
                :template => false
            })

            clone_spec.config        = RbVmomi::VIM.VirtualMachineConfigSpec(:deviceChange => Array.new)
            clone_spec.customization = generate_custom_spec(clone_spec, vm_config)

            clone_spec
        end

        # Generate the Customization Specification.
        #
        # == Parameters:
        # clone_spec::
        #   the clone specification passed by #generate_clone_spec.
        #
        # vm_config::
        #   The vm configuration for the new VM.
        #
        def generate_custom_spec(clone_spec, vm_config)
            src_config = @vm.config

            global_ipset = RbVmomi::VIM.CustomizationGlobalIPSettings
            cust_spec    = RbVmomi::VIM.CustomizationSpec(:globalIPSettings => global_ipset)

            cust_spec.globalIPSettings.dnsServerList = vm_config[:ip_dns].split(',') if vm_config[:ip_dns]
            cust_spec.globalIPSettings.dnsSuffixList = vm_config[:domain].split(',')

            nicSettingMap = []
            src_cards     = []
            src_config.hardware.device.each do |dev|
                if dev.deviceInfo.label =~ /^Network adapter/
                    src_cards << dev.deviceInfo.label
                end
            end

            src_cards.each do |name|
                puts name
                if vm_config[:network]
                    config = vm_config[:network][name]
                else
                    config = nil
                end

                card = src_config.hardware.device.find { |d| d.deviceInfo.label == name }
                unless card
                    raise Vsimple::Error.new "Can't find source network card #{name} to customize"
                end

                if config && config[:port_group]
                    network = find_network(config[:port_group])
                    begin
                        switch_port = RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
                            :switchUuid   => network.config.distributedVirtualSwitch.uuid,
                            :portgroupKey => network.key
                        )
                        card.backing.port = switch_port
                    rescue
                        card.backing.deviceName = network.name
                    end
                else
                    switch_port = RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
                        :switchUuid   => card.backing.port.switchUuid,
                        :portgroupKey => card.backing.port.portgroupKey
                    )
                    card.backing.port = switch_port
                end

                clone_spec.config.deviceChange.push RbVmomi::VIM.VirtualDeviceConfigSpec(
                    :device    => card,
                    :operation => "edit"
                )

                if config && config[:ip]
                    nicSettingMap << generate_adapter_map(config[:ip], config[:gw])
                else
                    cam            = RbVmomi::VIM.CustomizationAdapterMapping
                    cam.adapter    = RbVmomi::VIM.CustomizationIPSettings
                    cam.adapter.ip = RbVmomi::VIM.CustomizationDhcpIpGenerator
                    nicSettingMap << cam
                end

            end

            cust_spec.nicSettingMap = nicSettingMap
            if is_windows?
                cust_spec.identity = generate_win_ident(vm_config)
                cust_spec.options  = generate_win_opts
            else
                cust_spec.identity = generate_linux_ident(vm_config)
            end

            cust_spec
        end

        def generate_win_ident(vm_config)
            ident = RbVmomi::VIM.CustomizationSysprep

            if vm_config[:commandList]
                guiRunOnce             = RbVmomi::VIM.CustomizationGuiRunOnce
                guiRunOnce.commandList = vm_config[:commandList]
                ident.guiRunOnce       = guiRunOnce
            else
                ident.guiRunOnce       = nil
            end

            guiUnattended                = RbVmomi::VIM.CustomizationGuiUnattended
            guiUnattended.autoLogon      = false
            guiUnattended.autoLogonCount = 1
            password                     = RbVmomi::VIM.CustomizationPassword
            password.plainText           = true
            password.value               = vm_config[:password]
            guiUnattended.password       = password
            guiUnattended.timeZone       = "#{vm_config[:timeZone]}"
            ident.guiUnattended          = guiUnattended

            identification                     = RbVmomi::VIM.CustomizationIdentification
            identification.domainAdmin         = vm_config[:identification_domainAdmin]
            identification.domainAdminPassword = vm_config[:identification_domainAdminPassword]
            identification.joinDomain          = vm_config[:identification_joinDomain]
            identification.joinWorkgroup       = vm_config[:identification_joinWorkgroup]
            ident.identification               = identification

            userData              = RbVmomi::VIM.CustomizationUserData

            computerName          = RbVmomi::VIM.CustomizationFixedName
            computerName.name     = vm_config[:hostname].upcase

            userData.computerName = computerName
            userData.fullName     = "#{vm_config[:hostname]}.#{vm_config[:domain]}"
            userData.orgName      = vm_config[:userData_orgName]
            userData.productId    = vm_config[:userData_productId]
            ident.userData        = userData
            ident
        end

        def generate_win_opts()
            new_windowsOptions                = RbVmomi::VIM.CustomizationWinOptions
            new_windowsOptions.changeSID      = true
            new_windowsOptions.deleteAccounts = false
            new_windowsOptions
        end

        def generate_linux_ident(vm_config)
            ident = RbVmomi::VIM.CustomizationLinuxPrep

            ident.hostName      = RbVmomi::VIM.CustomizationFixedName
            ident.hostName.name = vm_config[:hostname]
            ident.domain        = vm_config[:domain]
            ident
        end

    end
end
