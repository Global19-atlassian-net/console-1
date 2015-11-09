class Pakyow::Console::DataType
  attr_reader :id, :name, :icon_class

  def initialize(name, icon_class, &block)
    @id = name
    @name = name
    @icon_class = icon_class
    @relations = {}
    @attributes = {}
    @nice_names = {}
    @extras = {}
    @actions = {}
    instance_exec(self, &block)
  end

  def related_to(name, as: nil)
    @relations[name] = as || name
  end

  def reference(&block)
    @reference = block
  end

  def attribute(name, type = nil, nice: nil, **extras)
    if type.nil?
      return {
        extras: @extras[name]
      }
    end

    @attributes[name] = type
    @nice_names[name] = nice unless nice.nil?
    @extras[name] = extras
  end

  def attributes
    @attributes.map { |attribute|
      {
        name: attribute[0],
        type: attribute[1],
        nice: @nice_names.fetch(attribute[0], Inflecto.humanize(attribute[0])),
        extras: @extras[attribute[0]],
      }
    }
  end

  def actions
    @actions.values
  end

  def [](var)
    instance_variable_get(:"@#{var}")
  end

  def model_object
    Object.const_get(model)
  end

  def display_name
    return nice_name unless pluralize?
    Inflecto.pluralize(nice_name)
  end

  def action(name, label: nil, notification: nil, display: nil, &block)
    @actions[name] = {
      name: name,
      label: label || Inflecto.humanize(name),
      notification: notification,
      display: display,
      logic: block,
    }
  end

  def nice_name(name = nil)
    if name.nil?
      @nice_name || Inflecto.humanize(Inflecto.underscore(self.name.to_s))
    else
      @nice_name = name
    end
  end

  def model(name = nil)
    return @model if name.nil?
    @model = name
  end

  def pluralize
    @pluralize = true
  end

  def hidden
    @hidden = true
  end

  def display?
    !@hidden
  end

  private

  def pluralize?
    @pluralize == true
  end
end
