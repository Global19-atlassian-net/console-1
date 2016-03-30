class Pakyow::Console::Plugin
  attr_reader :id, :name, :functions, :readme
  attr_accessor :version, :mountable, :routes

  def [](var)
    instance_variable_get(:"@#{var}")
  end

  def initialize(name, path, &block)
    @id = name
    @name = name
    @path = path
    @routes = []
    # @functions = {}

    @readme = File.read(File.join( path, '../../', 'README.md'))

    instance_exec(self, &block)
  end

  def boot(&block)
    if block_given?
      @boot_block = block
    else
      @boot_block.call
    end
  end

  # def function(name, options = {}, &block)
  #   @functions[name] = {
  #     block: block,
  #     options: options
  #   }
  # end

  # def invoke(fn_name, context, options)
  #   context.instance_exec(options, &@functions[fn_name.to_sym][:block])
  # end

  private

  def config(&block)
    Pakyow::Config.register(name) do |config|
      config.instance_exec(&block)
    end
  end
end
