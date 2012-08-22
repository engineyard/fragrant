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

    def vaction(route)
      route.route_path.split(/[\/\(]/)[2].capitalize
    end

    def vcmd(route, v, a = [])
      verb = vaction(route)
      cmd = Vagrant::Command.const_get(verb).new(a, v)
    end

    def venv(id)
      Vagrant::Environment.new({ :cwd => File.join(boxdir, id) })
    end

  end

  resource :environments do

    desc "Destroys a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    delete '/destroy/:id' do
      # TODO: argv --force
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Lists Vagrant environments"
    get :list do
      envglob
    end

    desc "Halts a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/halt/:id' do
      # TODO: argv --force
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Initializes a Vagrant environment"
    post :init do
      machine = envrand
      Dir.mkdir(File.join(boxdir, machine), 0755)
      v = venv(machine)
      cmd = vcmd(route, v, [boxname, boxurl])
      cmd.execute
      machine
    end

    desc "Provisions a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/provision/:id' do
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Reloads a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/reload/:id' do
      # TODO: argv --[no-]provision, --provision-with x,y,z
      v = venv(params[:id])
      cmd = vmcd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Resumes a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/resume/:id' do
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Prints the status of a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    get '/status/:id' do
      v = venv(params[:id])
      { :state => v.vms[:default].state }
    end

    desc "Suspends a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/suspend/:id' do
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

    desc "Boots a Vagrant environment"
    params do
      # TODO: add regex to validate id
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
    end
    post '/up/:id' do
      # TODO: argv --[no-]provision, --provision-with x,y,z
      v = venv(params[:id])
      cmd = vcmd(route, v)
      cmd.execute
      params[:id]
    end

  end

  resource :vms do

    desc "Lists registered virtual machines"
    get :registered do
      out = %x{VBoxManage list vms}
      out.split('\n')
    end

    desc "Lists running virtual machines"
    get :running do
      out = %x{VBoxManage list runningvms}
      out.split('\n')
    end

  end

end
