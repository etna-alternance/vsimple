# Vsimple

Simple version of rbvmomi easy to use vpshere.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vsimple'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vsimple

## Usage

```
require "vsimple"

config = {
    :host => "172.16.1.1",
    :user => "USER",
    :pass => "PASS"
}

Vsimple.connect(config)

Vsimple.set_dc("DATACENTER")
Vsimple.set_cluster("cluster")

vm = Vsimple::VM.new("template/debian-7.3-amd64")
begin
    vm.clone("vms/new_vm.vsimple.fr", {
        :powerOn => true,
        :network => {
            "Network adapter 1" => {
                :port_group => "ext",
                :ip         => "192.168.42.42/24",
                :gw         => "192.168.42.254",
            }
        }
    })
rescue Vsimple::Error => e
    puts e.msg
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/etna-alternance/vsimple )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
