module Pakyow::Helpers
  def errors
    @errors
  end

  def error_object_type
    @error_object_type
  end

  def handle_errors(view, object_type: nil, object_id: nil)
    @error_object_type = object_type

    q = {
      object_type: object_type,
      object_id: object_id,
    }

    unless current_console_user.nil?
      q[:user_id] = current_console_user.id
    end

    if req.socket? && @errors && !@errors.empty?
      ui.mutated(:errors, self)
    else
      view.scope(:errors).mutate(:list, with: data(:errors).all).subscribe(q)
    end
  end

  def gravatar_url(hash)
    if Pakyow.app.env == :development
      d = 'retro'
    else
      # d = CGI::escape("http://#{request.env['HTTP_HOST']}/images/avatar-default.png")
      d = 'retro'
    end

    "//gravatar.com/avatar/#{hash}?d=#{d}"
  end

  #TODO move this somewhere else
  def invoke(plugin, function, options = {})
    #TODO mixin default option values
    Pakyow::Console::PluginRegistry.find(plugin).invoke(function, self, options)
  end

  def setup_toolbar(view)
    begin
      view = view.partial(:toolbar)
    rescue NoMethodError
    end

    view.scope(:'pw-user').bind(current_console_user)

    # collaborator presence
    view.scope(:collaborator).mutate(:list, with: data(:collaborator).all).subscribe
  end
end
