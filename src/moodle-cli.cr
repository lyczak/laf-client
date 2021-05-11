require "crotp"
require "yaml"
require "duo-client"

require "./moodle-client"
require "./cas-client"

class Config
  include YAML::Serializable

  property username : String
  property password : String
  property duo_device : String # "phone1"
  property hotp_secret : String
  property hotp_count : Int32
end

config_path = ARGV[0]? || "config.yml"

puts "Loading config file..."
if !File.exists?(config_path)
  raise "Failed to find config file: #{config_path}"
end

config_string = File.read(config_path)

config = Config.from_yaml(config_string)

cc = Cas::Client.new "service=https%3A%2F%2Fmoodle.lafayette.edu%2Flogin%2Findex.php"

puts "Loading CAS..."
cc.fetch_exec_token

puts "Logging into CAS..."
dc = cc.submit_credentials(config.username, config.password)

puts "Loading Duo..."
dc.fetch_iframe

puts "Fetching Duo challenge..."
dc.start_session

hotp = CrOTP::HOTP.new(config.hotp_secret)
hotp_token = hotp.generate(config.hotp_count)
config.hotp_count += 1
File.write(config_path, config.to_yaml, mode: "w")

puts "Submitting Duo HOTP code..."
dc.submit_token(config.duo_device, hotp_token)

puts "Checking for Duo success..."
duo_status = dc.fetch_status

puts "Fetching Duo result..."
duo_result = dc.fetch_result(duo_status.response.not_nil!.result_url.not_nil!)

puts "Submitting Duo result to CAS..."
ticket_uri = cc.submit_duo_resp(duo_result)

mc = Moodle::Client.new URI.parse ticket_uri

puts "Submitting CAS ticket to Moodle..."
mc.submit_ticket

puts "Logging into Moodle..."
mc.do_login

puts "Fetching Moodle key..."
mc.fetch_sesskey

puts "Fetching Moodle events..."
events_resp = mc.fetch_events

puts "Done!"

puts "Upcoming events:"
events_resp.each { |r|
  r.data.events.each { |e|
    puts "#{e.timestart.to_local.to_s("%m/%d %H:%M")} #{e.name}"
  }
}
