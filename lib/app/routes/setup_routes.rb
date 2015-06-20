Pakyow::App.routes :setup do
  include Pakyow::Console::SharedRoutes

  namespace :console, '/console' do
    get :setup, '/setup' do
      redirect router.group(:console).path(:login) if setup?

      # setup the form
      view.scope(:user).bind(@user || {})
      handle_errors(view)
    end

    get :setup_platform, '/setup/platform' do
      redirect router.group(:console).path(:login) if setup?
      redirect router.group(:console).path(:setup_token) unless platform_token?

      view.scope(:app).apply(platform_client.apps)
    end

    get :setup_token, '/setup/token' do
      redirect router.group(:console).path(:login) if setup?
      redirect router.group(:console).path(:setup_platform) if platform_token?
    end

    post '/setup/token' do
      redirect router.group(:console).path(:login) if setup?
      redirect router.group(:console).path(:setup_platform) if platform_token?

      email = params[:email]
      token = params[:token]

      client = platform_client(email, token)

      if client.valid_token?
        auth = { email: email, token: token }
        file = File.expand_path('~/.pakyow')
        File.open(file, 'w').write(auth.to_json)
        redirect router.group(:console).path(:setup_platform)
      else
        #TODO present error message
        redirect router.group(:console).path(:setup_token)
      end
    end

    get :setup_app, '/setup/app/:app_id' do
      redirect router.group(:console).path(:login) if setup?
      redirect router.group(:console).path(:setup_token) unless platform_token?

      if app = platform_client.app(params[:app_id])
        opts = {
          app: {
            id: app[:id]
          }
        }
        File.open('./.platform', 'w').write(opts.to_json)
        redirect '/console'
      else
        res.status = 404
      end
    end

    post :setup, '/setup' do
      @user = Pakyow::Auth::User.new(params[:user])
      @user.role = Pakyow::Auth::User::ROLES[:admin]

      if @user.valid?
        @user.save
        auth(@user)

        redirect router.group(:console).path(:dashboard)
      else
        @errors = @user.errors
        reroute router.group(:console).path(:setup), :get
      end
    end
  end
end
