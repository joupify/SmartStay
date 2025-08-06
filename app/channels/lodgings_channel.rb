class LodgingsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "lodgings_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
