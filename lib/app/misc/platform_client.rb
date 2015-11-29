class PlatformClient
  class << self
    def auth(email, password)
      response = HTTParty.post(File.join(PLATFORM_URL, 'auth/token'), body: {
        login: email,
        password: password,
      })

      if response.code == 200
        Hash.strhash(JSON.parse(response.body))[:access_token]
      end
    end
  end

  def initialize(email, token, info)
    @email = email
    @token = token
    @info  = info
  end

  def valid?
    response = HTTParty.get(File.join(PLATFORM_URL, 'api/apps'), basic_auth: {
      username: @email,
      password: @token,
    })

    response.code == 200
  end

  def socket
    if app = @info[:app]
      response = HTTParty.post(File.join(PLATFORM_URL, 'api/apps', app[:id].to_s, 'socket'), basic_auth: {
        username: @email,
        password: @token,
      })

      Hash.strhash(JSON.parse(response.body))
    else
      {}
    end
  end

  # TODO: refactor to `projects`
  def apps
    response = HTTParty.get(File.join(PLATFORM_URL, 'api/projects'), basic_auth: {
      username: @email,
      password: @token,
    })

    JSON.parse(response.body).map { |app|
      Hash.strhash(app)
    }
  end

  # TODO: refactor to `project`
  def app(id)
    response = HTTParty.get(File.join(PLATFORM_URL, 'api/projects', id.to_s), basic_auth: {
      username: @email,
      password: @token,
    })

    Hash.strhash(JSON.parse(response.body))
  end

  def events
    if app = @info[:app]
      response = HTTParty.get(File.join(PLATFORM_URL, "api/projects/#{app[:id]}", 'events'), basic_auth: {
        username: @email,
        password: @token,
      })

      JSON.parse(response.body).map { |event|
        event = Hash.strhash(event)
        event[:created_at] = DateTime.parse(event[:created_at]).to_time
        event
      }
    else
      []
    end
  end

  def collaborators
    if app = @info[:app]
      response = HTTParty.get(File.join(PLATFORM_URL, "api/projects/#{app[:id]}", 'collaborators'), basic_auth: {
        username: @email,
        password: @token,
      })

      JSON.parse(response.body).map { |app|
        Hash.strhash(app)
      }
    else
      []
    end
  end

  def releases
    if app = @info[:app]
      response = HTTParty.get(File.join(PLATFORM_URL, "api/projects/#{app[:id]}", 'releases'), basic_auth: {
        username: @email,
        password: @token,
      })

      JSON.parse(response.body).map { |release|
        release = Hash.strhash(release)
        release[:created_at] = DateTime.parse(release[:created_at]).to_time
        release
      }
    end
  end

  def create_release
    response = HTTParty.post(File.join(PLATFORM_URL, 'api/projects', @info[:app][:id].to_s, 'releases'), basic_auth: {
      username: @email,
      password: @token,
    })

    Hash.strhash(JSON.parse(response.body))
  end

  def update_release(id, body)
    response = HTTParty.patch(File.join(PLATFORM_URL, 'api/projects', @info[:app][:id].to_s, 'releases', id.to_s), basic_auth: {
      username: @email,
      password: @token,
    }, body: { release: body })

    Hash.strhash(JSON.parse(response.body))
  end
end
