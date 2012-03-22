# pop emails off of a mail server and create a ticket in
# an unfuddle project for each one
# requires the 'tmail' gem to be installed
require 'rubygems'
require 'net/https'
require 'net/pop'
require 'tmail'

UNFUDDLE_SETTINGS = {
  :subdomain  => 'mysubdomain',
  :username   => 'username',
  :password   => 'password',
  :ssl        => true,
  :project_id => 1234
}

POP3_SETTINGS = {
  :server     => 'pop.myserver.com',
  :port       => 110,
  :username   => 'myusername',
  :password   => 'mypassword',
  :delete     => false
}

def xml_escape(s); s.gsub('&', '&amp;').gsub('<','&lt;').gsub('>', '&gt;'); end

http = Net::HTTP.new("#{UNFUDDLE_SETTINGS[:subdomain]}.unfuddle.com", UNFUDDLE_SETTINGS[:ssl] ? 443 : 80)

# if using ssl, then set it up
if UNFUDDLE_SETTINGS[:ssl]
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
end

# connect to the pop3 server and create a ticket per email
# then optionally delete the message off the server
# the format of the xml could get a lot more robust (components, severities, more info from the tmail object, etc.)
Net::POP3.start(POP3_SETTINGS[:server], POP3_SETTINGS[:port], POP3_SETTINGS[:username], POP3_SETTINGS[:password]) do |pop|
  pop.each_mail { |message|
    email = TMail::Mail.parse(message.pop)
    request = Net::HTTP::Post.new("/api/v1/projects/#{UNFUDDLE_SETTINGS[:project_id]}/tickets", {'Content-type' => 'application/xml'})
    request.basic_auth UNFUDDLE_SETTINGS[:username], UNFUDDLE_SETTINGS[:password]
    request.body = "<ticket><priority>1</priority><summary>#{xml_escape(email.subject)}</summary><description>From: #{xml_escape(email.from.join(','))}\n\n#{xml_escape(email.body)}</description></ticket>"
    response = http.request(request)
    if response.code == "201"
      puts "Message Created: #{response['Location']}"
      message.delete if POP3_SETTINGS[:delete]
   else
    # hmmm...we must have done something wrong
      puts "HTTP Status Code: #{response.code}."
    end
  }
end