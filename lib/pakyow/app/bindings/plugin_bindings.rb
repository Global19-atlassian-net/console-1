Pakyow::App.bindings :'console-plugin' do
  scope :'console-plugin' do
    restful :'console-plugin'

    binding :version do
      "(v#{bindable[:version]})"
    end

    binding :'show-href' do
      { href: router.group(:'console-plugin').path(:show, :'console-plugin_id' => bindable.name) }
    end

    binding :readme do |value|
      Pakyow.app.presenter.processor_store[:md].call(value)
    end
  end
end
