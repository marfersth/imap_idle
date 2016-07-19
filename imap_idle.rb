# Ruby script to fetch IMAP mails with IDLE mode.
# Was done originally to generate an automatic email response
# to any email that arrives to noreply@host.com
#
# Before run the script set necessary environment variables:
#     $ export ENV_VAR_NAME=<value>
# Then just run the script
#   2. run the script:
#     $ ruby idle_map.rb

# default rails environment to development
ENV['RAILS_ENV'] ||= 'development'
require 'net/imap'
require 'net/http'
require 'mail'
require 'time'
include AdminsMailer

@debug = false

# return timestamp in ISO8601 with precision in milliseconds
def time_now
  Time.now.utc.iso8601(3)
end

# make a connection to imap account
def imap_connect(server, username, password)
  imap = Net::IMAP.new(server, 993, true)
  Net::IMAP.debug = @debug

  capabilities = imap.capability
  puts "imap capabilities: #{capabilities.join(',')}" if @debug

  unless capabilities.include? "IDLE"
    puts "'IDLE' IMAP capability not available in server"
    imap.disconnect
    exit
  end

  imap.login(username, password)
  imap
end

def send_response_email(receiver_email)
  # this method was used to send an automatic response for emails received
  # to noreply mailbox, but you could process the email received as you want here
end

# watch for any mail that arrives to the specified folder, receive it and then delete it
def idle_loop(imap, server, username, password, folder)
  loop do
    begin
      imap.select(folder)

      imap.idle do |resp|
        puts resp.inspect if @debug
        # Got something. Send DONE. This breaks you out of the blocking call
        imap.idle_done
      end

      imap.uid_search(["UNDELETED"]).each do |uid|
        msg   = imap.uid_fetch(uid, ['RFC822']).first.attr['RFC822']
        email = Mail.read_from_string msg
        sender_email = email.from.first

        # tag email to delete
        imap.uid_store(uid, "+FLAGS", [:Deleted])

        # process arrived email
        send_response_email(sender_email)
      end

        # expunge removes the deleted emails
        imap.expunge

    rescue SignalException => e
      puts "Signal received at #{time_now}: #{e.class}. #{e.message}"

    rescue Net::IMAP::Error => e
      puts "Net::IMAP::Error at #{time_now}: #{e.class}. #{e.message}"
      # timeout ? reopen connection
      imap = imap_connect(server, username, password)
      puts "reconnected to server"

    rescue Exception => e
      puts "Something went wrong at #{time_now}: #{e.class}. #{e.message}"
      imap = imap_connect(server, username, password)
      puts "reconnected to server"
    end
  end
end


###
###  Main
###
server = ENV['SERVER'] ||= 'imap.gmail.com'
username = ENV['USERNAME']
password = ENV['PW']
folder = ENV['FOLDER'] ||= 'INBOX'

if !password or !username
  puts "specify USERNAME and PW env vars"
  exit
end

puts "\n      imap server: #{server}"
puts "         username: #{username}"
puts "           folder: #{folder}"

imap = imap_connect(server, username, password)

idle_loop(imap, server, username, password, folder)