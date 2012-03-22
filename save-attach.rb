def receive(email)
    #email.attachments are TMail::Attachment
    #but they ignore a text/mail parts.
    @attachments = ''

    email.parts.each_with_index do |part, index|
      filename = part_filename(part)
      filename ||= "#{index}.#{ext(part)}"
      filename = "#{Time.now.strftime("%Y%m%d%H%M%S")}-" + filename
      filepath = "#{RAILS_ROOT}/public/attachements/#{filename}"
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
