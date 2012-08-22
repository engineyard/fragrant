require 'spec_helper'

describe Fragrant do
  include Rack::Test::Methods

  def app
    Fragrant
  end

  describe "GET /vms/registered" do
    it "returns an array of registered vms" do
      get "/vms/registered"
      last_response.status.should == 200
      JSON.parse(last_response.body).should be_kind_of(Array)
    end
  end

  describe "GET /vms/running" do
    it "returns an array of running vms" do
      get "/vms/running"
      last_response.status.should == 200
      JSON.parse(last_response.body).should be_kind_of(Array)
    end
  end

end
