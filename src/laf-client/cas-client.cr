require "http/client"
require "myhtml"
require "duo-client"

class Cas::Client
  VERSION = "0.1"

  def initialize(
    query_params : URI::Params | String,
    @user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"
  )
    @cas_uri = URI.new "https", "cas.lafayette.edu", path: "/cas/login", query: query_params
    @execution_login = ""
    @execution_duo = ""

    @sig_request = [] of String
  end

  # Fetch the (first) CSRF token, needed prior to submitting credentials. Execute this first.
  def fetch_exec_token
    response = HTTP::Client.get @cas_uri

    cas_login_form = Myhtml::Parser.new(response.body)

    @execution_login = cas_login_form.css("input[type=hidden][name=execution]").to_a.pop.attribute_by("value").not_nil!
  end

  # Attempt a sign-in with a given *username* and *password*, obtaining a Duo::Client if successful.
  # You are responsible for using the Duo::Client to complete the two-factor challenge.
  def submit_credentials(username, password)
    form_data = URI::Params.build do |form|
      form.add "username", username
      form.add "password", password
      form.add "execution", @execution_login
      form.add "_eventId", "submit"
      form.add "geolocation", ""
    end

    headers = HTTP::Headers{
      "Host"                      => "cas.lafayette.edu",
      "User-Agent"                => @user_agent,
      "Accept"                    => "text/html,application/xhtml+xml,application/xml;q=>0.9,image/webp,*/*;q=>0.8",
      "Accept-Language"           => "en-US,en;q=>0.5",
      "Content-Type"              => "application/x-www-form-urlencoded",
      "Origin"                    => "https://cas.lafayette.edu",
      "DNT"                       => "1",
      "Connection"                => "keep-alive",
      "Referer"                   => @cas_uri.to_s,
      "Upgrade-Insecure-Requests" => "1",
      "Pragma"                    => "no-cache",
      "Cache-Control"             => "no-cache",
      "TE"                        => "Trailers",
    }

    # post credentials to login page
    response = HTTP::Client.post(@cas_uri, headers, form_data)

    cas_duo_page = Myhtml::Parser.new(response.body)

    # this changes after posting credentials the first time:
    @execution_duo = cas_duo_page.css("input[type=hidden][name=execution]").to_a.pop.attribute_by("value").not_nil!
    duo_iframe = cas_duo_page.css("#duo_iframe").to_a.pop

    sr_attrib = duo_iframe.attribute_by("data-sig-request")

    if (sr_attrib.nil?)
      raise "Failed to find duo data-sig-request attribute on iframe"
    end

    @sig_request = sr_attrib.split(":")

    return Duo::Client.from_iframe(duo_iframe, @cas_uri.to_s)
  end

  # Submit a `Duo::Resp(Duo::ResultResp)`, *duo_result* after completing the two-factor challenge.
  # If successful, recieve the redirect URL indicating where to proceed to.
  def submit_duo_resp(duo_result : Duo::Resp(Duo::ResultResp))
    if duo_result.response.nil?
      raise "duo_result must contain valid response"
    end


    form_data = URI::Params.build do |form|
      form.add "execution", @execution_duo
      form.add "_eventId", "submit"
      form.add "geolocation", ""
      form.add "signedDuoResponse", "#{duo_result.response.not_nil!.cookie}:#{@sig_request[1]}"
    end
    
    # puts form_data.pretty_inspect
    
    cas_result_headers = HTTP::Headers{
      "Host"                      => "cas.lafayette.edu",
      "User-Agent"                => @user_agent,
      "Accept"                    => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Language"           => "en-US,en;q=0.5",
      "Content-Type"              => "application/x-www-form-urlencoded",
      "Origin"                    => "https://cas.lafayette.edu",
      "DNT"                       => "1",
      "Connection"                => "keep-alive",
      "Referer"                   => @cas_uri.to_s,
      "Upgrade-Insecure-Requests" => "1",
      "Pragma"                    => "no-cache",
      "Cache-Control"             => "no-cache",
      "TE"                        => "Trailers",
    }
    
    response = HTTP::Client.post(@cas_uri, cas_result_headers, form_data)

    if response.headers["Location"].nil?
      raise "no final CAS redirect!"
    end
    
    return response.headers["Location"]
  end
end
