require 'grape'
require 'uuid'
require 'vagrant'

class Fragrant < Grape::API
  version 'v1', :using => :header, :vendor => 'nextgen'
  format :json

  helpers do

    def boxdir
      @boxdir ||= File.expand_path(File.join(File.dirname(__FILE__), 'vboxes'))
    end

    def boxname
      @boxname ||= 'nextgen64'
    end

    def boxurl
      @boxurl ||= 'http://shunterus.s3.amazonaws.com/nextgen64.box'
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

    def venv(id)
      Vagrant::Environment.new({ :cwd => File.join(boxdir, id) })
    end

  end

  resource :environments do

    desc "Destroys a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    delete '/destroy/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Destroy.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Lists Vagrant environments"
    get :list do
      envglob
    end

    desc "Halts Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/halt/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Halt.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Initializes a Vagrant environment"
    post :init do
      machine = envrand
      Dir.mkdir(File.join(boxdir, machine), 0755)
      v = venv(machine)
      cmd = Vagrant::Command::Init.new([], v)
      cmd.execute
      machine
    end

    desc "Provisions Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/provision/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Provision.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Reloads Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/reload/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Reload.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Resumes Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/resume/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Resume.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Prints status of Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    get '/status/:id' do
      v = venv(params[:id])
      { :state => v.vms[:default].state }
    end

    desc "Suspends Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/suspend/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Suspend.new([], v)
      cmd.execute
      params[:id]
    end

    desc "Boots Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String
    end
    post '/up/:id' do
      v = venv(params[:id])
      cmd = Vagrant::Command::Up.new([], v)
      cmd.execute
      params[:id]
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
