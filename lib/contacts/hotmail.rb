require 'nokogiri'

class Contacts
  class Hotmail < Base
    URL                 = "https://login.live.com/login.srf?id=2"
    OLD_CONTACT_LIST_URL = "http://%s/cgi-bin/addresses"
    NEW_CONTACT_LIST_URL = "http://%s/mail/GetContacts.aspx"
    CONTACT_LIST_URL = "http://mpeople.live.com/default.aspx?pg=0"
    COMPOSE_URL         = "http://%s/cgi-bin/compose?"
    PROTOCOL_ERROR      = "Hotmail has changed its protocols, please upgrade this library first. If that does not work, report this error at http://rubyforge.org/forum/?group_id=2693"
    PWDPAD = "IfYouAreReadingThisYouHaveTooMuchFreeTime"
    MAX_HTTP_THREADS    = 8

    def real_connect
      data, resp, cookies, forward = get(URL)
      old_url = URL
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end

      postdata =  "PPSX=%s&PwdPad=%s&login=%s&passwd=%s&LoginOptions=2&PPFT=%s" % [
        CGI.escape(data.split("><").grep(/PPSX/).first[/=\S+$/][2..-3]),
        PWDPAD[0...(PWDPAD.length-@password.length)],
        CGI.escape(login),
        CGI.escape(password),
        CGI.escape(data.split("><").grep(/PPFT/).first[/=\S+$/][2..-3])
      ]

      form_url = data.split("><").grep(/form/).first.split[5][8..-2]
      data, resp, cookies, forward = post(form_url, postdata, cookies)

      old_url = form_url
      until cookies =~ /; PPAuth=/ || forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end

      if data.index("The e-mail address or password is incorrect")
        raise AuthenticationError, "Username and password do not match"
      elsif data != ""
        raise AuthenticationError, "Required field must not be blank"
      elsif cookies == ""
        raise ConnectionError, PROTOCOL_ERROR
      end

      data, resp, cookies, forward = get("http://mail.live.com/mail", cookies)
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end


      @domain = URI.parse(old_url).host
      @cookies = cookies
    rescue AuthenticationError => m
      if @attempt == 1
        retry
      else
        raise m
      end
    end

    def contacts(options = {})
      if connected?
        in_the_loop = true
        index = 0
        @contacts = []

        while in_the_loop do
          data, resp, cookies, forward = get(get_contact_list_url(index), @cookies)

          if resp.code_type != Net::HTTPOK
            raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
          end

          @contacts += contacts_from_page data
          in_the_loop = data.match(/ContactList_next/)
          index += 1
        end
        return @contacts.select{|contact| contact[1].present?}
      end
    end

    def get_contact_list_url(index)
      "http://mpeople.live.com/default.aspx?pg=#{index}"
    end

    private

    def contacts_from_page page
      @html = Nokogiri::HTML page
      contacts = @html.css('tr td:last-child div a').
        map {|link| parse_row link.attribute("id").to_s.sub('elk', '')}
    end

    def parse_row row_number
      [parse_name_by_row(row_number), parse_email_by_row(row_number)]
    end

    def parse_email_by_row row_number
      email_from_hotmail_url(@html.css("a#elk"+row_number).attribute('href').value)
    end

    def parse_name_by_row row_number
      @html.css("a#dnlk"+row_number).text
    end

    def email_from_hotmail_url url
      CGI::unescape CGI::unescape url.match(/to=(.*)&ru/)[1]
    end

    TYPES[:hotmail] = Hotmail
  end
end
