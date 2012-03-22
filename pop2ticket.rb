# pop emails off of a mail server and create a ticket in
# an unfuddle project for each one
# requires the 'tmail' gem to be installed
require 'rubygems'
require 'net/https'
require 'net/pop'
require 'tmail'
require 'rest-client'

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
  :username   => 'jblanco999',
  :password   => 'mypassword',
  :delete     => false
}

def receive(email)
    #email.attachments are TMail::Attachment
    #but they ignore a text/mail parts.
    @attachments = ''

    email.parts.each_with_index do |part, index|
      filename = part_filename(part)
      filename ||= "#{index}.#{ext(part)}"
      filename = "#{Time.now.strftime("%Y%m%d%H%M%S")}-" + filename
      filepath = "./attachements/#{filename}"
      @attachments = @attachments + "|" + filename
      puts "WRITING: #{filepath}"
      #File.open( fn, "w+b", 0644 ) { |f| f.write tattch.body.decoded }
      File.open(filepath,File::CREAT|File::TRUNC|File::WRONLY,0644) do |f|
        f.write(part.body).decoded
      end
    end

    return @attachments
end

  # part is a TMail::Mail
def part_filename(part)
    # This is how TMail::Attachment gets a filename
    file_name = (part['content-location'] &&
      part['content-location'].body) ||
      part.sub_header("content-type", "name") ||
      part.sub_header("content-disposition", "filename")
end

    CTYPE_TO_EXT = {
      'image/jpeg' => 'jpg',
      'image/gif'  => 'gif',
      'image/png'  => 'png',
      'image/tiff' => 'tif'
    }

def ext( mail )
        CTYPE_TO_EXT[mail.content_type] || 'txt'
end

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
      attachments = receive(email)
      attachments do |filename|
#        RestClient.post '/data', :myfile => File.new("/path/to/image.jpg", 'rb')
#        private_resource = RestClient::Resource.new 'https://example.com/private/resource', 'user', 'pass'
#        private_resource.put File.read('pic.jpg'), :content_type => 'image/jpg'
        upload = Net::HTTP::Post.new("#{response['Location']}/attachments/upload", {'Content-type' => 'application/octet-stream'}, {'Accept' => 'application/xml'})
        upload.basic_auth UNFUDDLE_SETTINGS[:username], UNFUDDLE_SETTINGS[:password]
      end
        message.delete if POP3_SETTINGS[:delete]
   else
    # hmmm...we must have done something wrong
      puts "HTTP Status Code: #{response.code}."
    end
  }
end