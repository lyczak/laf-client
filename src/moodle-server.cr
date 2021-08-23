require "crotp"
require "yaml"
require "duo-client"

require "./laf-client"

require "http/server"
require "router"

class Config
  include YAML::Serializable

  property username : String
  property password : String
  property duo_device : String # "phone1"
  property hotp_secret : String
  property hotp_count : Int32
end

class MoodleServer
  include Router

  @log_handler = HTTP::LogHandler.new()

  @config_path = "config.yml"
  @mc : Moodle::Client | Nil

  def initialize
    puts "Loading config file..."
    if !File.exists?(@config_path)
      raise "Failed to find config file: #{@config_path}"
    end

    config_string = File.read(@config_path)

    @config = Config.from_yaml(config_string)
  end

  def draw_routes
    get "/" do |context, _|
      context.response.print "It works!"
      context
    end

    get "/events" do |context, _|
      if @mc.nil?
        context.response.respond_with_status(HTTP::Status::UNAUTHORIZED)
      else
        events_resp = @mc.not_nil!.fetch_events
        context.response.print events_resp.to_json
        context.response.content_type= "application/json"
      end

      context
    end

    post "/cas" do |context, _|
      cc = Cas::Client.new "service=https%3A%2F%2Fmoodle.lafayette.edu%2Flogin%2Findex.php"

      puts "Loading CAS..."
      cc.fetch_exec_token

      puts "Logging into CAS..."
      dc = cc.submit_credentials(@config.username, @config.password)

      puts "Loading Duo..."
      dc.fetch_iframe

      puts "Fetching Duo challenge..."
      dc.start_session

      hotp = CrOTP::HOTP.new(@config.hotp_secret)
      hotp_token = hotp.generate(@config.hotp_count)
      @config.hotp_count += 1
      File.write(@config_path, @config.to_yaml, mode: "w")

      puts "Submitting Duo HOTP code..."
      dc.submit_token(@config.duo_device, hotp_token)

      puts "Checking for Duo success..."
      duo_status = dc.fetch_status

      puts "Fetching Duo result..."
      duo_result = dc.fetch_result(duo_status.response.not_nil!.result_url.not_nil!)

      puts "Submitting Duo result to CAS..."
      ticket_uri = cc.submit_duo_resp(duo_result)

      @mc = Moodle::Client.new URI.parse ticket_uri

      puts "Submitting CAS ticket to Moodle..."
      @mc.not_nil!.submit_ticket

      puts "Logging into Moodle..."
      @mc.not_nil!.do_login

      puts "Fetching Moodle key..."
      @mc.not_nil!.fetch_sesskey

      context.response.print "Success!"

      context
    end
  end

  def run
    draw_routes

    handlers = [
      @log_handler,
      route_handler,
    ]

    server = HTTP::Server.new(handlers)
    server.bind_tcp("127.0.0.1", 3000)
    server.listen
  end
end

moodle_server = MoodleServer.new
moodle_server.run