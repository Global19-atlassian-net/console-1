Pakyow::App.mutable :file do
  query :all_of_type do |type|
    type = type.to_s
    Pakyow::Console::FileStore.instance.all.select { |f|
      f[:type] == type && f[:context] == Pakyow::Console::FileStore::CONTEXT_MEDIA
    }.sort { |a, b| a[:filename].downcase <=> b[:filename].downcase }
  end

  action :create do |name, file|
    Pakyow::Console::FileStore.instance.store(name, file, context: Pakyow::Console::FileStore::CONTEXT_MEDIA)
  end

  action :delete do |id|
    Pakyow::Console::FileStore.instance.delete(id)
  end
end
