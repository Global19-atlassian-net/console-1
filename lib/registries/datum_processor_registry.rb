module Pakyow::Console::DatumProcessorRegistry
  def self.register(*types, &block)
    types.each do |type|
      datum_processors[type] = block
    end
  end

  def self.process(params, datum = {}, as: nil)
    as.attributes(datum).inject({}) do |acc, attribute|
      name = attribute[:name]
      type = attribute[:type]

      field = attribute[:extras][:relationship] || name
      setter = attribute[:extras][:setter]

      if setter
        setter.call(datum, params)
      else
        begin
          acc[field] = datum_processors.fetch(type).call(params[name], datum[name])
        rescue KeyError
          acc[field] = params[name] if params.key?(name.to_s)
        end
      end

      acc
    end
  end

  def self.reset
    @datum_processors = nil
  end

  private

  def self.datum_processors
    @datum_processors ||= {}
  end
end
