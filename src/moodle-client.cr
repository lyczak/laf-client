require "http/client"
require "myhtml"
require "json"

require "./moodle-models"

class Moodle::Client
    @my_uri : URI
    @host : String

    def initialize(
        @login_uri : URI,
        @user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36")
        
        @cookies = HTTP::Cookies.new
        @sesskey = ""

        @host = @login_uri.host.not_nil!
        @base_uri = URI.new @login_uri.scheme, @host, @login_uri.port
        @my_uri = @base_uri.dup
        @my_uri.path = "/my/"
    end

    def submit_ticket()
        headers = HTTP::Headers {
            "Host" => @host,
            "User-Agent" => @user_agent,
            "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language" => "en-US,en;q=0.5",
            "Referer" => "https://cas.lafayette.edu/", # TODO: can we remove this?
            "DNT" => "1",
            "Connection" => "keep-alive",
            "Cookie" => "CasGoogleAnalytics=https://web-analytics.lafayette.edu/affiliation/student",
            "Upgrade-Insecure-Requests" => "1",
            "Pragma" => "no-cache",
            "Cache-Control" => "no-cache",
        }

        response = HTTP::Client.get(@login_uri, headers)

        @cookies.fill_from_server_headers(response.headers)
    end

    def do_login()
        @login_uri.query = "" # TODO: is there a better way to handle state here?

        headers = HTTP::Headers {
            "Host" => @host,
            "User-Agent" => @user_agent,
            "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language" => "en-US,en;q=0.5",
            "Referer" => "https://cas.lafayette.edu/",
            "DNT" => "1",
            "Connection" => "keep-alive",
            "Upgrade-Insecure-Requests" => "1",
            "Pragma" => "no-cache",
            "Cache-Control" => "no-cache",
            "TE" => "Trailers",
        }

        @cookies.add_request_headers(headers)

        response = HTTP::Client.get(@login_uri, headers)

        @cookies.fill_from_server_headers(response.headers)

        @login_uri = URI.parse response.headers["Location"]

        @cookies.add_request_headers(headers)

        response = HTTP::Client.get(@login_uri, headers)

        @cookies.fill_from_server_headers(response.headers)
    end

    def fetch_sesskey()
        headers = HTTP::Headers {
            "Host" => @host,
            "User-Agent" => @user_agent,
            "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language" => "en-US,en;q=0.5",
            "Connection" => "keep-alive",
            "Upgrade-Insecure-Requests" => "1",
            "DNT" => "1",
            "Sec-GPC" => "1",
            "Pragma" => "no-cache",
            "Cache-Control" => "no-cache",
            "TE" => "Trailers",
        }

        @cookies.add_request_headers(headers)

        response = HTTP::Client.get(@my_uri, headers)

        my_page = Myhtml::Parser.new(response.body)
        @sesskey = my_page.css("input[type=hidden][name=sesskey]").to_a.pop.attribute_by("value").not_nil!
    end

    def fetch_events()
        url_params = URI::Params.new({
            "sesskey" => [ @sesskey ],
            "info" => [ Moodle::MethodNames::EVENTS_BY_TIMESORT ]
        })

        events_uri = @base_uri.dup
        events_uri.path = "/lib/ajax/service.php"
        events_uri.query_params = url_params

        headers = HTTP::Headers {
            "Host" => @host,
            "User-Agent" => @user_agent,
            "Accept" => "application/json, text/javascript, */*; q=0.01",
            "Accept-Language" => "en-US,en;q=0.5",
            "Content-Type" => "application/json",
            "X-Requested-With" => "XMLHttpRequest",
            "Origin" => "https://moodle.lafayette.edu",
            "DNT" => "1",
            "Connection" => "keep-alive",
            "Referer" => "https://moodle.lafayette.edu/my/",
            "Pragma" => "no-cache",
            "Cache-Control" => "no-cache",
            "TE" => "Trailers",
        }

        @cookies.add_request_headers(headers)

        t_now = Time.utc
        req_args = Moodle::EventsByTimesortArgs.new(7_u32, t_now, t_now + Time::Span.new(days: 14))

        events_req = Moodle::Req(Moodle::EventsByTimesortArgs).new(Moodle::MethodNames::EVENTS_BY_TIMESORT, req_args)

        req_body = [events_req].to_json
        headers["Content-Length"] = req_body.size.to_s

        response = HTTP::Client.post(events_uri, headers, body: req_body)

        Array(Moodle::Resp(Moodle::Events)).from_json response.body
    end
end