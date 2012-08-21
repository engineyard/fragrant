require 'spec_helper'

describe Fragrant do
  include Rack::Test::Methods

  def app
    Fragrant
  end

  describe "GET /environments/list" do
    it "returns an array of Vagrant environments" do
      get "/environments/list"
      last_response.status.should == 200
      JSON.parse(last_response.body).should be_kind_of(Array)
    end
  end

end
