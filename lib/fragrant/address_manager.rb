require 'ipaddr'
require 'json'

module Fragrant
  AddressRangeExhausted = Class.new(StandardError)

  class AddressManager
    attr_accessor :data_location, :allocated_addresses
    attr_accessor :address_range, :address_map

    def initialize(data_location, address_range)
      self.data_location = data_location
      self.address_range = address_range
      self.address_map = {}
      self.allocated_addresses = []
      load_address_data
    end

    def load_address_data
      return unless File.exist?(data_location)
      unless File.writable?(data_location)
        raise "Unable to access IP address config file at #{data_location}"
      end
      File.open(data_location, 'rb') do |f|
        data = JSON.parse(f.read)
        self.address_range = data['address_range']
        self.address_map = data['address_map']
        self.allocated_addresses = data['allocated_addresses']
      end
    end

    def address_data
      {:address_range => address_range,
       :allocated_addresses => allocated_addresses,
       :address_map => address_map}
    end

    def first_available_address
      ip = IPAddr.new(address_range).to_range.detect do |ip|
        !allocated_addresses.include?(ip.to_s)
      end
      return ip.to_s if ip
      raise AddressRangeExhausted, "No more addresses available in range #{address_range}"
    end

    def persist
      dir = File.dirname(data_location)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.open(data_location, 'wb') do |f|
        f.write(address_data.to_json)
      end
    end

    def claim_address(environment_id)
      if address_map.key?(environment_id)
        raise "#{environment_id} already has an address"
      end
      address = first_available_address
      address_map[environment_id] = address
      allocated_addresses << address
      persist
      address
    end

    def release_addresses(environment_id)
      unless address_map.key?(environment_id)
        raise "No addresses registered to environment #{environment_id}"
      end

      address = address_map[environment_id]
      allocated_addresses.delete address
      address_map.delete environment_id
      persist
    end
  end
end
