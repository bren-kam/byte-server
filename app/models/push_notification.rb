class PushNotification < ActiveRecord::Base
  # A PushNotification uses the Parse API to send a standard
  # push notification message to the mobile devices of all 
  # subscribers of a given "channel."  
  # Byte's channels correspond to specific application resources, 
  # such as restaurant locations, menu items, and users.


  #############################
  ###  ATTRIBUTES
  #############################
  attr_accessible :notification_type, :message, :additional_data
  serialize :additional_data # a hash that might include the push_notifiable_type


  #############################
  ###  ASSOCIATIONS
  #############################
  belongs_to :push_notifiable, polymorphic: true


  #############################
  ###  VALIDATIONS
  #############################
  validates :notification_type, presence: true, inclusion: { in: PUSH_NOTIFICATION_TYPES }
  validates :push_notifiable_type, presence: true, inclusion: { in: PUSH_NOTIFIABLE_TYPES }
  validates :push_notifiable_id, presence: true, numericality: { only_integer: true }
  validates :message, presence: true


  #############################
  ###  INSTANCE METHODS
  #############################
  def dispatch
    # You can use this method with something like: 
    # Item.push_notifications.create(message: 'Great new price!').dispatch
    # but the more common way is the dispatch_message_to_resource_subscribers
    # class method (see below).
    # NOTE: We are using Parse's "Advanced Targeting" because we
    # only want to send push notifications to users whose preferences
    # allow them.

    # Create the push notification object
    data = {
      alert: message,
      pushtype: notification_type,
      # title: 'TBD',
      sound: 'chime',
      badge: 'Increment',
    }
    data.merge!(additional_data) if additional_data.present?
    push = Parse::Push.new(data)

    # Advanced Targeting parameters
    # (See the "Sending Pushes to Queries" subsection of:
    # https://parse.com/docs/push_guide#sending-queries/REST )
    # The User must be subscribed to the given channel and accept notifications of
    # the given type, and notifications may only be sent to the User's current device.
    query = Parse::Query.new(Parse::Protocol::CLASS_INSTALLATION).
      eq('channels', PushNotificationSubscription.channel_name_for(push_notifiable)). # 'channels' is an array but the Parse documentation indicates it may be used this way
      eq('push_notification_types', notification_type) # This should work the same way as 'channels'; an array that can be used without 'include' sytax
    push.where = query.where

    # Send the push notification to all currently-active subscriber devices
    push.save

    return true
  end


  #############################
  ###  CLASS METHODS
  #############################

  def self.dispatch_message_to_resource_subscribers(notification_type, message, resource, additional_data_hash = {})
    # You can use this method with something like: 
    # PushNotification.dispatch_message_to_resource_subscribers('fav_item_on_special', 'Great new price!', item)

    return false unless self.resource_is_valid?(resource)

    resource.push_notifications.create({
      notification_type: notification_type, 
      message: message, 
      additional_data: additional_data_hash
    }).dispatch
  end

  def self.resource_is_valid?(resource)
    PUSH_NOTIFIABLE_TYPES.include?(resource.class.to_s)
  end
end