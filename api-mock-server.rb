require 'json'

module ApiMockServer

  class Endpoint
    include Mongoid::Document

    field :verb, type: String
    field :pattern, type: String
    field :response, type: String
    field :status, type: Integer
    field :params, type: Hash

    VALID_HTTP_VERBS = %w{get post put delete patch}

    validates_presence_of :response, :status, message: "不能为空"
    validates_inclusion_of :verb, in: VALID_HTTP_VERBS , message: "目前只支持以下方法: #{VALID_HTTP_VERBS.join(", ")}"
    validates_format_of :pattern, with: /\A\/\S*\Z/, message: "必须为 / 开头的合法 url"
    validates_uniqueness_of :pattern, scope: [:verb], message: "和 verbs 该组合已经存在"

    def self.init_endpoint args
      args, ps = fixed_args args
      args = args.merge(params: ps)
      new(args)
    end

    def update_endpoint args
      args, ps = fixed_args args
      args = args.merge(params: ps) unless ps.empty?
      update_attributes(args)
    end

    private
    def self.fixed_args args
      ps ||= {}
      (args["params_key"]||[]).each_with_index do |params_name, index|
        ps[params_name] = args["params_value"][index]
      end
      ps = ps.delete_if {|k, v| k.blank? }
      args["status"] = args["status"].blank? ? 200 : args["status"].to_i
      args = args.extract!("verb", "pattern", "response", "status")
      return args, ps
    end

    def fixed_args args
      self.class.fixed_args args
    end

  end

  class App < Sinatra::Base
    register Sinatra::Partial
    use Rack::MethodOverride

    configure :development do
      set :partial_template_engine, :erb

      Mongoid.load!("mongoid.yml")
    end

    helpers do
      def restart_server
        File.open("rerun.rb", "w") do |file|
          file.write Time.now
        end
      end
    end

    # remove it
    require 'seed'

    get "/admin" do
      erb :index
    end

    get "/admin/new" do
      @route = Endpoint.new
      erb :new
    end

    post "/admin/new" do
      @route = Endpoint.init_endpoint(params["route"])
      if @route.save
        restart_server
        erb :show
      else
        @error = @route.errors.full_messages
        erb :new
      end
    end

    get "/admin/:id/edit" do
      @route = Endpoint.find(params[:id])
      erb :edit
    end

    post "/admin/:id/edit" do
      @route = Endpoint.find(params[:id])
      if @route.update_endpoint(params[:route])
        erb :show
      else
        @error = @route.errors.full_messages
        erb :edit
      end
    end

    delete "/admin/:id" do
      content_type :json
      @route = Endpoint.find(params[:id])
      if @route.destroy
        {error: '删除成功', url: '/admin'}.to_json
      else
        {error: @route.errors.full_messages.join(", "), url: '/admin'+params[:id]}.to_json
      end
    end

    get "/admin/:id" do
      @route = Endpoint.find params[:id]
      erb :show
    end

    Endpoint.each do |endpoint|
      send(endpoint.verb, endpoint.pattern) do
        content_type :json
        status endpoint.status
        endpoint.response
      end
    end
  end

end
