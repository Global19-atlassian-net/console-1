# require 'pakyow-support'
# require 'pakyow-core'
# require 'pakyow-presenter'
# require 'pakyow-realtime'
# require 'pakyow-ui'

# require 'pakyow-assets'
# require 'pakyow-slim'

require 'sequel'
Sequel::Model.plugin :timestamps, update_on_create: true

require 'image_size'

CONSOLE_ROOT = File.expand_path('../', __FILE__)
PLATFORM_URL = 'https://pakyow.com'

Pakyow::App.config.presenter.view_stores[:console] = [File.join(CONSOLE_ROOT, 'views')]

require_relative 'version'

Pakyow::Assets.preprocessor :eot, :svg, :ttf, :woff, :woff2, :otf

module Pakyow
  module Console
    def self.loader
      @loader ||= Pakyow::Loader.new
    end

    def self.load_paths
      @load_paths ||= []
    end

    def self.migration_paths
      @migration_paths ||= []
    end

    def self.imports
      @imports ||= []
    end

    def self.add_load_path(path)
      load_paths << path
    end

    def self.add_migration_path(path)
      migration_paths << path
    end

    def self.boot_plugins
      PluginRegistry.boot
    end

    def self.model(name)
      Object.const_get(Pakyow::Config.console.models[name])
    end

    def self.before(object, action, &block)
      ServiceHookRegistry.register :before, action, object, &block
    end

    def self.after(object, action, &block)
      ServiceHookRegistry.register :after, action, object, &block
    end

    def self.data(type, icon: nil, &block)
      DataTypeRegistry.register type, icon_class: icon, &block
    end

    def self.editor(*types, &block)
      EditorRegistry.register *types, &block
    end

    def self.script(path)
      ScriptRegistry.register path
    end

    def self.db
      return @db unless @db.nil?

      Pakyow.logger.info '[console] establishing database connection'

      @db = Sequel.connect(ENV.fetch('DATABASE_URL'))
      @db.extension :pg_json

      Sequel.default_timezone = :utc
      Sequel::Model.plugin :validation_helpers
      Sequel::Model.plugin :timestamps, update_on_create: true
      Sequel::Model.plugin :uuid
      Sequel.extension :pg_json_ops

      @db
    end

    def self.pages
      @pages ||= Pakyow::Console::Page.where(published: true).all
    end

    def self.invalidate_pages
      @pages = nil
    end
  end
end

require_relative 'data_type'
require_relative 'panel'
require_relative 'plugin'
require_relative 'route'
require_relative 'config'
require_relative 'file_store'

require_relative 'registries/data_type_registry'
require_relative 'registries/editor_registry'
require_relative 'registries/panel_registry'
require_relative 'registries/plugin_registry'
require_relative 'registries/route_registry'
require_relative 'registries/datum_processor_registry'
require_relative 'registries/datum_formatter_registry'
require_relative 'registries/service_hook_registry'
require_relative 'registries/content_type_registry'
require_relative 'registries/script_registry'

require_relative 'editors/string_editor'
require_relative 'editors/text_editor'
require_relative 'editors/enum_editor'
require_relative 'editors/boolean_editor'
require_relative 'editors/monetary_editor'
require_relative 'editors/file_editor'
require_relative 'editors/percentage_editor'
require_relative 'editors/html_editor'
require_relative 'editors/sensitive_editor'
require_relative 'editors/relation_editor'
require_relative 'editors/content_editor'
require_relative 'editors/date_editor'

require_relative 'formatters/percentage_formatter'

require_relative 'processors/boolean_processor'
require_relative 'processors/file_processor'
require_relative 'processors/float_processor'
require_relative 'processors/percentage_processor'
require_relative 'processors/relation_processor'

Pakyow::Console::PanelRegistry.register :release, mode: :development, nice_name: 'Release', icon_class: 'paper-plane' do; end

app_path = File.join(CONSOLE_ROOT, 'app')

Pakyow::Console.add_load_path(app_path)

CLOSING_HEAD_REGEX = /<\/head>/m
CLOSING_BODY_REGEX = /<\/body>/m

# make sure this after configure block executes first
# FIXME: need an api for this on Pakyow::App
Pakyow::App.hook(:after, :configure).unshift(lambda  {
  config.assets.stores[:console] = File.expand_path('../app/assets', __FILE__)

  begin
    config.app.db
  rescue Pakyow::ConfigError
    config.app.db = Pakyow::Console.db
  end

  app_migration_dir = File.join(config.app.root, 'migrations')

  if Pakyow::Config.env == :development
    unless File.exists?(app_migration_dir)
      FileUtils.mkdir(app_migration_dir)
      app_migrations = []
    end

    migration_map = {}
    console_migration_dir = File.expand_path('../migrations', __FILE__)
    migration_paths = Pakyow::Console.migration_paths.push(console_migration_dir)
    console_migrations = []

    migration_paths.each do |migration_path|
      console_migrations.concat Dir.glob(File.join(migration_path, '*.rb')).map { |path|
        basename = File.basename(path)
        migration_map[basename] = path
        basename
      }
    end

    app_migrations = Dir.glob(File.join(app_migration_dir, '*.rb')).map { |path|
      File.basename(path)
    }

    (console_migrations - app_migrations).each do |migration|
      Pakyow.logger.info "[console] copying migration #{migration}"
      FileUtils.cp(migration_map[migration], app_migration_dir)
    end
  end

  begin
    Pakyow.logger.info '[console] checking for missing migrations'
    Sequel.extension :migration
    Sequel::Migrator.check_current(config.app.db, app_migration_dir)
  rescue Sequel::DatabaseConnectionError
    Pakyow.logger.warn '[console] could not connect to database'
    next
  rescue Sequel::Migrator::NotCurrentError
    Pakyow.logger.info '[console] not current; running migrations now'
    Sequel::Migrator.run(config.app.db, app_migration_dir)
  end

  Pakyow.logger.info '[console] migrations are current'
})

Pakyow::App.after :init do
  if Pakyow::Config.env == :development
    if info = platform_creds
      @context = Pakyow::AppContext.new
      setup_platform_socket(info)
    end
  end
end

Pakyow::App.after :process do
  if req.path_parts[0] != 'console' && @presenter && @presenter.presented? && console_authed? && res.body && res.body.is_a?(Array)
    view = Pakyow::Presenter::ViewContext.new(Pakyow::Presenter::View.new(File.open(File.join(CONSOLE_ROOT, 'views', 'console', '_toolbar.slim')).read, format: :slim), self)
    setup_toolbar(view)

    console_css = '<link href="/console/styles/console-toolbar.css" rel="stylesheet" type="text/css">'

    if config.assets.compile_on_startup
      console_css = Pakyow::Assets.mixin_fingerprints(console_css)
    end

    font_css = '<link href="//fonts.googleapis.com/css?family=Open+Sans:400italic,400,300,600,700" rel="stylesheet" type="text/css">'
    fa_css = '<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css">'

    body = res.body[0]
    body.gsub!(CLOSING_HEAD_REGEX, console_css + font_css + fa_css + '</head>')
    body.gsub!(CLOSING_BODY_REGEX, view.to_html + '</body>')
  end
end

Pakyow::App.before :load do
  Pakyow::Console.boot_plugins
end

Pakyow::App.after :load do
  Pakyow::Console.load_paths.each do |path|
    Pakyow::Console.loader.load_from_path(path)
  end

  # make sure the console routes are last (since they have the catch-all)
  Pakyow::App.routes[:console] = Pakyow::App.routes.delete(:console)

  unless Pakyow::Console::DataTypeRegistry.names.include?(:user)
    Pakyow::Console::DataTypeRegistry.register :user, icon_class: 'users' do
      model Pakyow::Config.console.models[:user]
      pluralize

      attribute :name, :string, nice: 'Full Name'
      attribute :username, :string
      attribute :email, :string
      attribute :password, :sensitive
      attribute :password_confirmation, :sensitive
      attribute :active, :boolean

      action :remove, label: 'Delete', notification: 'user deleted' do
        reroute router.group(:datum).path(:remove, data_id: params[:data_id], datum_id: params[:datum_id])
      end
    end
  end

  unless Pakyow::Console::DataTypeRegistry.names.include?(:page)
    Pakyow::Console::DataTypeRegistry.register :page, icon_class: 'columns' do
      model Pakyow::Config.console.models[:page]
      pluralize

      attribute :name, :string

      # TODO: make the slug editable on the edit page only
      # attribute :slug, :string

      # TODO: add more user-friendly template descriptions (embedded in the top-matter?)
      attribute :page, :relation, class: Pakyow::Config.console.models[:page], nice: 'Parent Page', relationship: :parent

      # TODO: (later) add configuration to containers so that content can be an image or whatever (look at GIRT)
      # TODO: (later) we definitely need the concept of content templates (perhaps in _content) or something
      attribute :template, :enum, values: Pakyow.app.presenter.store.templates.keys.map { |k| [k,k] }.unshift(['', ''])

      # TODO: render a unique content editor per container
      #   we're currently setting the single content editor under `default` for compatibility
      attribute :content, :content

      # TODO: we need a metadata editor with the ability for the user to add k / v OR for the editor to define keys

      action :publish,
             label: 'Publish',
             notification: 'page published',
             display: ->(page) { !page.published? } do |page|
        page.published = true
        page.save

        Pakyow::Console.invalidate_pages
      end

      action :unpublish,
             label: 'Unpublish',
             notification: 'page unpublished',
             display: ->(page) { page.published? } do |page|
        page.published = false
        page.save

        Pakyow::Console.invalidate_pages
      end
    end
  end

  editables = {}
  presenter.store(:default).views do |view, path|
    editables = view.doc.editables
    next if editables.empty?

    page = Pakyow::Console::Page.where(slug: path).first
    next unless page.nil?

    composer = presenter.store(:default).composer(path)

    # TODO: support multiple editables
    # this will take place once the pw-content table is created
    # each editable would have an associated content record and
    # would be isomorphicly related to the page (this will also
    # solve the multiple container problem)

    content = {
      id: SecureRandom.uuid,
      scope: :content,
    }

    editable = editables.first

    # TODO: I think this is where we'd check for editable-parts

    content[:type] = :default
    content[:content] = editables.first[:doc].to_html

    page = Pakyow::Console::Page.new
    page.slug = path
    page.name = path.split('/').last
    page.template = composer.page.info[:template] || :default
    puts editables.first.inspect
    page.content = [content]
    page.published = true
    page.save
  end

  # TODO: we need a navigation datatype; this would let you build a navigation containing particular
  #   pages, plugin endpoints, etc; essentially anything that registers a route with console.
  #   the items could be ordered with each navigation.
  #   nested pages would be taken into account somehow.
  #   we'd need to figure out the rendering; perhaps we'll have to define navigation types (extendable)...
end

Pakyow::App.before :error do
  if req.path_parts[0] == 'console'
    if !Pakyow::Config.app.errors_in_browser
      presenter.path = 'console/errors/500'
      res.body << presenter.view.composed.to_html
      halt
    end
  end
end

Pakyow::App.after :route do
  if !found? && req.path_parts[0] == 'console'
    presenter.path = 'console/errors/404'
    res.body << presenter.view.composed.to_html
    halt
  end
end

# plugin stubs

# Pakyow::Console::PanelRegistry.register :design, mode: :development, nice_name: 'Design', icon_class: 'eye' do; end
# Pakyow::Console::PanelRegistry.register :plugins, mode: :development, nice_name: 'Plugins', icon_class: 'plug' do; end

# Pakyow::Console::PanelRegistry.register :content, mode: :production, nice_name: 'Pages', icon_class: 'newspaper-o' do; end
# Pakyow::Console::PanelRegistry.register :stats, mode: :production, nice_name: 'Stats', icon_class: 'bar-chart' do; end

Pakyow::Presenter::StringDocParser::SIGNIFICANT << :editable?

module Pakyow
  module Presenter
    class StringDocParser
      private

      def editable?(node)
        return false unless node['data-editable']
        return true
      end
    end

    class StringDoc
      def editables
        find_editables(@node ? [@node] : @structure)
      end

      private

      def find_editables(structure, primary_structure = @structure, editables = [])
        ret_editables = structure.inject(editables) { |s, e|
          if e[1].has_key?(:'data-editable')
            s << {
              doc: StringDoc.from_structure(primary_structure, node: e),
              editable: e[1][:'data-editable'].to_sym,
            }
          end
          find_editables(e[2], e[2], s)
          s
        } || []

        ret_editables
      end
    end
  end
end
