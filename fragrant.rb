require 'grape'
require 'uuid'

class Fragrant < Grape::API
  version 'v1', :using => :header, :vendor => 'nextgen'
  format :json

  helpers do

    def boxdir
      @boxdir ||= File.expand_path(File.join(File.dirname(__FILE__), 'vboxes'))
    end

    def envglob
      Dir.entries(boxdir).select do |d|
        next if d.start_with?('.')
        File.exists?(File.join(boxdir, d, 'Vagrantfile'))
      end
    end

    def envrand
      UUID.generate
    end

  end

  resource :environments do

    desc "Lists Vagrant environments"
    get :list do
      envglob
    end

    desc "Creates a Vagrant environment"
    post :new do
      machine = envrand
      Dir.mkdir(File.join(boxdir, machine), 0755)
      File.open(File.join(boxdir, machine, 'Vagrantfile'), 'w') {}
      machine
    end

    desc "Removes a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    get '/rm/:id' do
      FileUtils.remove_entry_secure(File.join(boxdir, params[:id])) if envglob.include?(params[:id])
    end

  end

  resource :vms do

    desc "Lists registered boxes"
    get :registered do
      %x{VBoxManage list vms}
    end

    desc "Lists running boxes"
    get :running do
      %x{VBoxManage list runningvms}
    end

  end

end
