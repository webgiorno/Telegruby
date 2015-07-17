require 'httmultiparty'
require 'json'

module Telegruby
  class Bot
    attr_accessor :id

    def initialize(api_token)
      @token = api_token
      @endpoint = "https://api.telegram.org/bot#{@token}/"
      @id = 0
    end

    # get updates using the offset id
    def get_updates(options = {})
      if options == {}
        options = {
          :offset => @id
        }
      end

      raw_data = self.get_request("getUpdates", options)
      update = Update.new(JSON.parse(raw_data, object_class: OpenStruct))
      
      if !update.result.empty?
        # there are updates, so mark them as 'seen'
        @id = (update.result.last.update_id + 1)
      end
      
      return update
    end

    # Send a plaintext message to a chat id
    def send_message(id, text, reply = nil)
      options = {
        :chat_id => id,
        :text => text
      }

      if !reply.nil?
        options.merge!(:reply_to_message_id => reply)
      end
      
      self.get_request("sendMessage", options)
    end
    
    # Sends a photo message to a chat id
    def send_photo(id, filename, reply = nil)
      options = {
        :chat_id => id,
        :photo => File.new(filename)
      }
      
      if !reply.nil?
        options.merge!(:reply_to_message_id => reply)
      end

      self.post_request("sendPhoto", options)
    end

    # Sends a photo from a byte string
    def send_photo_bytestring(id, str, reply = nil)
      Tempfile.open(["img", ".jpg"]) { |f|
        f.binmode
        f.write(str)
       
        options = {
          :chat_id => id,
          :photo => File.new(f.path)
        }

        if !reply.nil?
          options.merge!(:reply_to_message_id => reply)
        end

        self.post_request("sendPhoto", options)
      }
    end

    protected

    # Provides a generic method for GET requests.
    def get_request(name, options = {})
      HTTMultiParty::get(@endpoint + name, query: options).body
    end

    # Provides a generic method for POST requests.
    def post_request(name, options = {})
      HTTMultiParty::post(@endpoint + name, query: options).body
    end
  end

  module_function

  # Reads an API token from a JSON file.
  # The result of this should be
  # passed to Telegruby::Bot.new
  def read_config(filename)
    begin
      data = JSON.parse(File.read(filename))

      if !data.key? "token"
        return false
      end

      return data
    rescue
      return false
    end
  end

  # Given an Update object, gets messages as structs.
  def collect_msgs(update)
    update.result.map { |msg|
      Message.new(msg)
    }
  end

  # Update object generated by
  # Telegruby::Bot::get_updates
  class Update < OpenStruct
    def results?
      !self.result.empty?
    end
  end

  # Message structure generated by
  # collect_msgs from an update hash.
  # Has some convenience methods.
  class Message < OpenStruct
    def initialize(hash_msg)
      super(hash_msg)
    end

    def timestamp
      self.message.date
    end

    def older_than?(secs)
      ((Time.now.to_i - self.timestamp) > secs)
    end

    def chat_id
      self.message.chat.id
    end

    def body
      self.message.text
    end

    def message_id
      self.message.message_id
    end
  end
end
